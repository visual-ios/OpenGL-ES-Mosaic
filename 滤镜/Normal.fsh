precision highp float;

uniform sampler2D Texture;
varying vec2 TextureCoordsVarying;

void main (void) {
    gl_FragColor = texture2D(Texture, TextureCoordsVarying);
}
