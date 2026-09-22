#include "gl_renderer.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const int kSourceViewFull = 0;
static const int kSourceViewCover = 1;
static const int kSourceViewCropCover = 2;

static const char *kVertexShader =
    "attribute vec2 aPosition;\n"
    "attribute vec2 aTexCoord;\n"
    "varying vec2 vTexCoord;\n"
    "void main() {\n"
    "  gl_Position = vec4(aPosition, 0.0, 1.0);\n"
    "  vTexCoord = aTexCoord;\n"
    "}\n";

static const char *kFragmentShader =
    "precision mediump float;\n"
    "varying vec2 vTexCoord;\n"
    "uniform sampler2D uTexture;\n"
    "uniform float uSwapRB;\n"
    "void main() {\n"
    "  vec4 c = texture2D(uTexture, vTexCoord);\n"
    "  if (uSwapRB > 0.5) c = vec4(c.b, c.g, c.r, c.a);\n"
    "  gl_FragColor = vec4(c.rgb, 1.0);\n"
    "}\n";

static float clampf_local(float value, float lo, float hi) {
    if (value < lo) return lo;
    if (value > hi) return hi;
    return value;
}

GlRenderer::GlRenderer()
    : program_(0), vertex_shader_(0), fragment_shader_(0), texture_(0),
      attr_position_(-1), attr_texcoord_(-1), uniform_texture_(-1),
      uniform_swap_rb_(-1), texture_width_(0), texture_height_(0),
      output_width_(0), output_height_(0), dest_width_(0), dest_height_(0),
      swap_rb_(false), ready_(false),
      source_view_mode_(kSourceViewFull), source_zoom_(1.0f),
      source_pan_x_(0.0f), source_pan_y_(0.0f),
      source_crop_left_(0.0f), source_crop_right_(0.0f),
      source_crop_top_(0.0f), source_crop_bottom_(0.0f),
      upload_buffer_(0), upload_buffer_bytes_(0) {
    memset(vertices_, 0, sizeof(vertices_));
    memset(texcoords_, 0, sizeof(texcoords_));
}

GlRenderer::~GlRenderer() {
    shutdown();
}

bool GlRenderer::compile_shader(GLuint shader, const char *source, const char *name) {
    glShaderSource(shader, 1, &source, 0);
    glCompileShader(shader);
    GLint ok = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (ok == GL_TRUE) return true;

    char log[1024];
    GLsizei n = 0;
    memset(log, 0, sizeof(log));
    glGetShaderInfoLog(shader, sizeof(log) - 1, &n, log);
    fprintf(stderr, "renderer: %s compile failed: %s\n", name, log);
    return false;
}

bool GlRenderer::init(int output_width, int output_height) {
    if (output_width <= 0 || output_height <= 0) return false;

    output_width_ = output_width;
    output_height_ = output_height;

    vertex_shader_ = glCreateShader(GL_VERTEX_SHADER);
    fragment_shader_ = glCreateShader(GL_FRAGMENT_SHADER);
    if (!vertex_shader_ || !fragment_shader_)
        return false;

    if (!compile_shader(vertex_shader_, kVertexShader, "vertex shader") ||
        !compile_shader(fragment_shader_, kFragmentShader, "fragment shader"))
        return false;

    program_ = glCreateProgram();
    glAttachShader(program_, vertex_shader_);
    glAttachShader(program_, fragment_shader_);
    glLinkProgram(program_);

    GLint linked = GL_FALSE;
    glGetProgramiv(program_, GL_LINK_STATUS, &linked);
    if (linked != GL_TRUE) {
        char log[1024];
        GLsizei n = 0;
        memset(log, 0, sizeof(log));
        glGetProgramInfoLog(program_, sizeof(log) - 1, &n, log);
        fprintf(stderr, "renderer: program link failed: %s\n", log);
        return false;
    }

    attr_position_ = glGetAttribLocation(program_, "aPosition");
    attr_texcoord_ = glGetAttribLocation(program_, "aTexCoord");
    uniform_texture_ = glGetUniformLocation(program_, "uTexture");
    uniform_swap_rb_ = glGetUniformLocation(program_, "uSwapRB");
    if (attr_position_ < 0 || attr_texcoord_ < 0 ||
        uniform_texture_ < 0 || uniform_swap_rb_ < 0) {
        fprintf(stderr, "renderer: shader attribute/uniform lookup failed\n");
        return false;
    }

    glGenTextures(1, &texture_);
    glBindTexture(GL_TEXTURE_2D, texture_);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glViewport(0, 0, output_width_, output_height_);

    ready_ = true;
    source_view_mode_ = kSourceViewFull;
    source_zoom_ = 1.0f;
    source_pan_x_ = 0.0f;
    source_pan_y_ = 0.0f;
    source_crop_left_ = source_crop_right_ = 0.0f;
    source_crop_top_ = source_crop_bottom_ = 0.0f;
    set_fullscreen_destination();
    set_source_view_full();

    fprintf(stderr, "renderer: GLES2 renderer initialized output=%dx%d\n",
            output_width_, output_height_);
    return true;
}

bool GlRenderer::ensure_upload_buffer(std::size_t bytes) {
    if (upload_buffer_ && upload_buffer_bytes_ >= bytes) return true;
    unsigned char *next = (unsigned char *)realloc(upload_buffer_, bytes);
    if (!next) return false;
    upload_buffer_ = next;
    upload_buffer_bytes_ = bytes;
    return true;
}

bool GlRenderer::upload_packed_rgba_bytes(const unsigned char *pixels,
                                          int width, int height,
                                          bool swap_rb) {
    if (!ready_ || !pixels || width <= 0 || height <= 0) return false;

    glBindTexture(GL_TEXTURE_2D, texture_);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    if (width != texture_width_ || height != texture_height_) {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
                     width, height, 0,
                     GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        texture_width_ = width;
        texture_height_ = height;
        if (!update_texcoords()) return false;
        fprintf(stderr, "renderer: texture allocated %dx%d\n", width, height);
    } else {
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0,
                        width, height,
                        GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    }

    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        fprintf(stderr, "renderer: texture upload GL error=0x%x\n", (unsigned)err);
        return false;
    }

    swap_rb_ = swap_rb;
    return true;
}

bool GlRenderer::upload_frame(const VideoFrame &frame) {
    if (!ready_ || !frame.data || frame.width <= 0 || frame.height <= 0 ||
        frame.stride < frame.width * 4) {
        return false;
    }

    const bool swap_rb =
        frame.format == PIXEL_FORMAT_BGRA8888 ||
        frame.format == PIXEL_FORMAT_BGRX8888;

    const unsigned char *pixels = frame.data;
    const int packed_stride = frame.width * 4;

    if (frame.stride != packed_stride) {
        const size_t bytes = (size_t)packed_stride * (size_t)frame.height;
        if (!ensure_upload_buffer(bytes)) {
            fprintf(stderr, "renderer: cannot allocate stride-pack buffer (%lu bytes)\n",
                    (unsigned long)bytes);
            return false;
        }
        for (int y = 0; y < frame.height; ++y) {
            memcpy(upload_buffer_ + (size_t)y * packed_stride,
                   frame.data + (size_t)y * frame.stride,
                   (size_t)packed_stride);
        }
        pixels = upload_buffer_;
    }

    return upload_packed_rgba_bytes(pixels, frame.width, frame.height, swap_rb);
}

bool GlRenderer::upload_rgba(const unsigned char *rgba, int width, int height) {
    VideoFrame frame;
    frame.data = rgba;
    frame.width = width;
    frame.height = height;
    frame.stride = width * 4;
    frame.format = PIXEL_FORMAT_RGBA8888;
    return upload_frame(frame);
}

bool GlRenderer::upload_test_grid(int width, int height) {
    if (width <= 0 || height <= 0) return false;

    const size_t bytes = (size_t)width * (size_t)height * 4u;
    unsigned char *pixels = (unsigned char *)malloc(bytes);
    if (!pixels) return false;

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            unsigned char r = 0, g = 0, b = 0;
            const int band = (x * 6) / width;
            switch (band) {
                case 0: r = 255; g = 0;   b = 0;   break;
                case 1: r = 255; g = 180; b = 0;   break;
                case 2: r = 0;   g = 220; b = 0;   break;
                case 3: r = 0;   g = 180; b = 255; break;
                case 4: r = 40;  g = 40;  b = 255; break;
                default:r = 200; g = 0;   b = 255; break;
            }

            if ((x % 60) < 2 || (y % 60) < 2) {
                r = g = b = 255;
            }
            if ((x > width / 2 - 5 && x < width / 2 + 5) ||
                (y > height / 2 - 5 && y < height / 2 + 5)) {
                r = g = b = 0;
            }

            const size_t off = ((size_t)y * width + x) * 4u;
            pixels[off + 0] = r;
            pixels[off + 1] = g;
            pixels[off + 2] = b;
            pixels[off + 3] = 255;
        }
    }

    const bool ok = upload_rgba(pixels, width, height);
    free(pixels);
    return ok;
}

bool GlRenderer::set_destination_rect(int x, int y, int width, int height) {
    if (output_width_ <= 0 || output_height_ <= 0 ||
        width <= 0 || height <= 0 ||
        x < 0 || y < 0 || x + width > output_width_ || y + height > output_height_) {
        return false;
    }

    const GLfloat left = -1.0f + 2.0f * (GLfloat)x / (GLfloat)output_width_;
    const GLfloat right = -1.0f + 2.0f * (GLfloat)(x + width) / (GLfloat)output_width_;
    const GLfloat top = 1.0f - 2.0f * (GLfloat)y / (GLfloat)output_height_;
    const GLfloat bottom = 1.0f - 2.0f * (GLfloat)(y + height) / (GLfloat)output_height_;

    vertices_[0] = left;  vertices_[1] = top;
    vertices_[2] = left;  vertices_[3] = bottom;
    vertices_[4] = right; vertices_[5] = top;
    vertices_[6] = right; vertices_[7] = bottom;

    dest_width_ = width;
    dest_height_ = height;
    return update_texcoords();
}

void GlRenderer::set_fullscreen_destination() {
    if (output_width_ > 0 && output_height_ > 0)
        set_destination_rect(0, 0, output_width_, output_height_);
}

bool GlRenderer::set_source_view_full() {
    source_view_mode_ = kSourceViewFull;
    source_zoom_ = 1.0f;
    source_pan_x_ = 0.0f;
    source_pan_y_ = 0.0f;
    return update_texcoords();
}

bool GlRenderer::set_source_view_cover(float zoom, float pan_x, float pan_y) {
    return set_source_view_crop_cover(
        0.0f, 0.0f, 0.0f, 0.0f, zoom, pan_x, pan_y);
}

bool GlRenderer::set_source_view_crop_cover(float crop_left, float crop_right,
                                            float crop_top, float crop_bottom,
                                            float zoom, float pan_x, float pan_y) {
    if (zoom < 1.0f || zoom > 4.0f ||
        pan_x < -1.0f || pan_x > 1.0f ||
        pan_y < -1.0f || pan_y > 1.0f ||
        crop_left < 0.0f || crop_left >= 0.45f ||
        crop_right < 0.0f || crop_right >= 0.45f ||
        crop_top < 0.0f || crop_top >= 0.45f ||
        crop_bottom < 0.0f || crop_bottom >= 0.45f ||
        crop_left + crop_right >= 0.90f ||
        crop_top + crop_bottom >= 0.90f) {
        return false;
    }

    source_view_mode_ =
        (crop_left == 0.0f && crop_right == 0.0f &&
         crop_top == 0.0f && crop_bottom == 0.0f)
        ? kSourceViewCover : kSourceViewCropCover;
    source_zoom_ = zoom;
    source_pan_x_ = pan_x;
    source_pan_y_ = pan_y;
    source_crop_left_ = crop_left;
    source_crop_right_ = crop_right;
    source_crop_top_ = crop_top;
    source_crop_bottom_ = crop_bottom;
    return update_texcoords();
}

bool GlRenderer::update_texcoords() {
    if (source_view_mode_ == kSourceViewFull ||
        texture_width_ <= 0 || texture_height_ <= 0 ||
        dest_width_ <= 0 || dest_height_ <= 0) {
        texcoords_[0] = 0.0f; texcoords_[1] = 0.0f;
        texcoords_[2] = 0.0f; texcoords_[3] = 1.0f;
        texcoords_[4] = 1.0f; texcoords_[5] = 0.0f;
        texcoords_[6] = 1.0f; texcoords_[7] = 1.0f;
        return true;
    }

    const float dest_aspect = (float)dest_width_ / (float)dest_height_;

    const float base_left = source_crop_left_;
    const float base_right = 1.0f - source_crop_right_;
    const float base_top = source_crop_top_;
    const float base_bottom = 1.0f - source_crop_bottom_;

    const float base_u_span = base_right - base_left;
    const float base_v_span = base_bottom - base_top;
    const float base_aspect =
        (base_u_span * (float)texture_width_) /
        (base_v_span * (float)texture_height_);

    float u_span = base_u_span;
    float v_span = base_v_span;

    /* COVER inside the user-trimmed source rectangle. This preserves aspect:
     * explicit crop margins are minimum trims; any extra cover crop is added
     * only on the axis required by the destination aspect ratio. */
    if (dest_aspect > base_aspect) {
        v_span = (base_u_span * (float)texture_width_) /
                 (dest_aspect * (float)texture_height_);
    } else if (dest_aspect < base_aspect) {
        u_span = (dest_aspect * base_v_span * (float)texture_height_) /
                 (float)texture_width_;
    }

    u_span /= source_zoom_;
    v_span /= source_zoom_;
    u_span = clampf_local(u_span, 0.05f, base_u_span);
    v_span = clampf_local(v_span, 0.05f, base_v_span);

    const float free_u = base_u_span - u_span;
    const float free_v = base_v_span - v_span;

    float left = base_left + free_u * (source_pan_x_ + 1.0f) * 0.5f;
    float top = base_top + free_v * (source_pan_y_ + 1.0f) * 0.5f;

    left = clampf_local(left, base_left, base_right - u_span);
    top = clampf_local(top, base_top, base_bottom - v_span);

    const float right = left + u_span;
    const float bottom = top + v_span;

    texcoords_[0] = left;  texcoords_[1] = top;
    texcoords_[2] = left;  texcoords_[3] = bottom;
    texcoords_[4] = right; texcoords_[5] = top;
    texcoords_[6] = right; texcoords_[7] = bottom;

    fprintf(stderr,
            "renderer: source crop-cover trim=(%.3f,%.3f,%.3f,%.3f) zoom=%.3f pan=(%.3f,%.3f) uv=[%.4f,%.4f..%.4f,%.4f]\n",
            source_crop_left_, source_crop_right_,
            source_crop_top_, source_crop_bottom_,
            source_zoom_, source_pan_x_, source_pan_y_,
            left, top, right, bottom);
    return true;
}

void GlRenderer::draw() {
    if (!ready_ || !texture_) return;

    glViewport(0, 0, output_width_, output_height_);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(program_);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture_);
    glUniform1i(uniform_texture_, 0);
    glUniform1f(uniform_swap_rb_, swap_rb_ ? 1.0f : 0.0f);

    glEnableVertexAttribArray((GLuint)attr_position_);
    glEnableVertexAttribArray((GLuint)attr_texcoord_);
    glVertexAttribPointer((GLuint)attr_position_, 2, GL_FLOAT, GL_FALSE, 0, vertices_);
    glVertexAttribPointer((GLuint)attr_texcoord_, 2, GL_FLOAT, GL_FALSE, 0, texcoords_);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glDisableVertexAttribArray((GLuint)attr_position_);
    glDisableVertexAttribArray((GLuint)attr_texcoord_);
}

void GlRenderer::shutdown() {
    if (texture_) {
        glDeleteTextures(1, &texture_);
        texture_ = 0;
    }
    if (program_) {
        glDeleteProgram(program_);
        program_ = 0;
    }
    if (vertex_shader_) {
        glDeleteShader(vertex_shader_);
        vertex_shader_ = 0;
    }
    if (fragment_shader_) {
        glDeleteShader(fragment_shader_);
        fragment_shader_ = 0;
    }
    if (upload_buffer_) {
        free(upload_buffer_);
        upload_buffer_ = 0;
    }
    upload_buffer_bytes_ = 0;
    texture_width_ = 0;
    texture_height_ = 0;
    output_width_ = 0;
    output_height_ = 0;
    dest_width_ = 0;
    dest_height_ = 0;
    source_view_mode_ = kSourceViewFull;
    source_zoom_ = 1.0f;
    source_pan_x_ = 0.0f;
    source_pan_y_ = 0.0f;
    source_crop_left_ = source_crop_right_ = 0.0f;
    source_crop_top_ = source_crop_bottom_ = 0.0f;
    swap_rb_ = false;
    ready_ = false;
}
