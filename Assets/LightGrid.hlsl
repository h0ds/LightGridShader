void LightGrid_float
    (UnityTexture2D source,
     float2 uv,
     float2 grid,
     float dotSize,
     out float3 outColor)
{
    // Grid coordinates / index
    float2 gc = uv * grid;
    float2 idx = floor(gc);

    // Color element selector
    float sel = frac(idx.x / 4);
    float3 mask = sel < 1.0 / 4 ? float3(1, 0, 0) :
                  sel < 2.0 / 4 ? float3(0, 1, 0) :
                  sel < 3.0 / 4 ? float3(0, 0, 1) : 0;

    // Color sample with quantized UV
    float2 q_uv = idx / grid;
    float4 src = SAMPLE_TEXTURE2D(source.tex, source.samplerstate, q_uv);

    // Distance from element edge
    float size = dotSize * 0.3;
    float dist = length(max(0, abs(frac(gc) - 0.5) - size));

    // Light level
    float level = 1 - smoothstep(0.1, 0.2, dist);

    // Vertical Shade
    float shade = saturate((frac(gc).y - 0.5) / (size + 0.5) + 0.5);

    outColor = src.rgb * mask * level * shade;
}

// Hash helpers for procedural noise (Metal-safe, avoid unsupported swizzles/overloads)
static float hash11(float p)
{
    return frac(sin(p * 127.1) * 43758.5453);
}

static float2 hash22(float2 p)
{
    float h = dot(p, float2(127.1, 311.7));
    float2 s = sin(float2(h, h + 1.0)) * 43758.5453;
    return frac(s);
}

// Extended variant with flicker/glitch controls. Backward compatible: original function remains unchanged.
// Parameters:
//  - time: global time (e.g., _Time.y)
//  - flickerIntensity: 0..1 (strength of brightness flicker)
//  - flickerSpeed: Hz (how quickly the flicker oscillates)
//  - glitchIntensity: 0..1 (strength of UV jitter/scanline glitch)
//  - glitchSpeed: Hz (how quickly the glitch pattern evolves)
void LightGridFlickerGlitch_float
    (UnityTexture2D source,
     float2 uv,
     float2 grid,
     float dotSize,
     float time,
     float flickerIntensity,
     float flickerSpeed,
     float glitchIntensity,
     float glitchSpeed,
     out float3 outColor)
{
    // Grid coordinates / index
    float2 gc = uv * grid;
    float2 idx = floor(gc);

    // Color element selector (same as base)
    float sel = frac(idx.x / 4);
    float3 mask = sel < 1.0 / 4 ? float3(1, 0, 0) :
                  sel < 2.0 / 4 ? float3(0, 1, 0) :
                  sel < 3.0 / 4 ? float3(0, 0, 1) : 0;

    // Quantized UV per-cell
    float2 q_uv = idx / grid;

    // Glitch: UV jitter within the cell based on time and index
    float tG = time * max(glitchSpeed, 0.0);
    float2 rnd = hash22(idx + float2(tG, tG * 1.37));
    float2 jitter = (rnd - 0.5) * (glitchIntensity / max(grid, float2(1.0, 1.0)));
    float2 g_uv = q_uv + jitter;

    float4 src = SAMPLE_TEXTURE2D(source.tex, source.samplerstate, g_uv);

    // Distance from element edge
    float size = dotSize * 0.3;
    float dist = length(max(0, abs(frac(gc) - 0.5) - size));

    // Light level
    float level = 1 - smoothstep(0.1, 0.2, dist);

    // Vertical shade
    float shade = saturate((frac(gc).y - 0.5) / (size + 0.5) + 0.5);

    // Flicker: brightness modulation per cell
    float tF = time * max(flickerSpeed, 0.0);
    float fNoise = hash11(idx.x * 7.1 + idx.y * 13.7) * 6.28318; // phase per cell
    float flicker = 1.0 - flickerIntensity * (0.5 + 0.5 * sin(tF + fNoise));

    outColor = src.rgb * mask * level * shade * flicker;
}
