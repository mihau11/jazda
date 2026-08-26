#version 330

out vec4 finalColor;

void main()
{
    // Only the depth buffer matters here - this framebuffer has no color
    // attachment (see Rlgl.ActiveDrawBuffers(0) at the call site).
    finalColor = vec4(1.0);
}
