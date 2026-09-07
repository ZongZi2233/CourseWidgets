#include <flutter/runtime_effect.glsl>

precision mediump float;

/*
  iOS 26 LIQUID GLASS INDICATOR SHADER - LITE (High Performance)
  ==============================================================
  
  Simplified version of interactive_indicator.frag for lower-end devices.
  
  CHANGES FROM FULL VERSION:
  - mediump precision (half the GPU register pressure)
  - Single background sample (no chromatic aberration / 3-tap)
  - Simplified edge distortion (linear falloff)
  - Simplified Fresnel (kept, but cheaper approximation)
  - Retains: SDF pill shape, edge refraction, rim highlights, glass tint, Fresnel glow
*/

// -----------------------------------------------------------------------------
// UNIFORMS (same interface as full version for drop-in replacement)
// -----------------------------------------------------------------------------
uniform vec2 uSize;
uniform vec2 uOrigin;
uniform vec4 uGlassColor;
uniform float uThickness;
uniform vec2 uLightDirection;
uniform float uLightIntensity;
uniform float uAmbientStrength;
uniform float uSaturation;
uniform float uRefractiveIndex;
uniform float uChromaticAberration; // accepted but ignored
uniform float uCornerRadius;
uniform vec2 uScale;
uniform float uGlowIntensity;
uniform float uDensityFactor;
uniform float uInteractionIntensity;
uniform vec2 uBackgroundOrigin;
uniform vec2 uBackgroundSize;
uniform float uHasBackground;

uniform float uAmbientRim;
uniform float uBaseAlphaMultiplier;
uniform float uEdgeAlphaMultiplier;
uniform float uRimThickness;
uniform float uRimSmoothing;

uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  // ---- COORDINATE SETUP ----
  vec2 fragPx = FlutterFragCoord().xy;
  vec2 localLogical = (fragPx - uOrigin) / uScale;
  vec2 center = uSize * 0.5;
  
  // ---- SDF PILL SHAPE ----
  vec2 halfSize = uSize * 0.5;
  vec2 q = abs(localLogical - halfSize) - halfSize + uCornerRadius;
  float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - uCornerRadius;

  float smoothing = 1.0 / uScale.x;
  float mask = 1.0 - smoothstep(-smoothing, smoothing, dist);
  
  if (mask <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  
  // ---- SURFACE NORMAL ----
  vec2 innerHalfSize = halfSize - uCornerRadius;
  vec2 p = localLogical - halfSize;
  vec2 closestOnSkeleton = clamp(p, -innerHalfSize, innerHalfSize);
  vec2 toEdge = p - closestOnSkeleton;
  float edgeLen = length(toEdge);
  vec2 surfaceNormal = (edgeLen > 0.001) ? normalize(toEdge) : vec2(0.0);
  
  // ---- EDGE DISTORTION (simplified linear) ----
  float distFromEdge = abs(dist);
  float edgeZone = 12.0;
  float edgeInfluence = clamp(1.0 - distFromEdge / edgeZone, 0.0, 1.0);
  
  float bendStrength = 0.5 * (0.6 + uInteractionIntensity * 0.4);
  vec2 edgeOffsetLogical = surfaceNormal * edgeInfluence * bendStrength * uSize.y * 0.3;
  
  // ---- SINGLE BACKGROUND SAMPLE (no chromatic aberration) ----
  vec2 posInBg = uBackgroundOrigin + localLogical;
  vec2 localRefracted = posInBg - edgeOffsetLogical;
  
  vec3 bg;
  if (uHasBackground > 0.5) {
    bg = texture(uTexture, localRefracted / uBackgroundSize).rgb;
  } else {
    bg = vec3(0.9);
  }
  
  // ---- LIGHTING (with simplified Fresnel) ----
  float edgeLightCatch = dot(surfaceNormal, uLightDirection);
  float keyHighlight = pow(max(edgeLightCatch, 0.0), 6.0) * uLightIntensity * 1.5;
  float rimBrightness = uAmbientRim + keyHighlight;
  
  // ---- FRESNEL EDGE GLOW (simplified) ----
  // Approximate Fresnel: brighter at edges where normal is perpendicular to view
  // Uses edgeInfluence as a proxy for the Fresnel term (cheaper than full dot product)
  float fresnelTerm = edgeInfluence * edgeInfluence; // squared for sharper falloff
  float fresnelGlow = fresnelTerm * uLightIntensity * 0.35;
  rimBrightness += fresnelGlow;
  
  // ---- HAIRLINE RIM ----
  float borderMask = 1.0 - smoothstep(0.0, smoothing * uRimSmoothing, distFromEdge - uRimThickness);
  vec3 rimColor = vec3(1.0) * rimBrightness * (uAmbientRim * 8.0);
  
  // ---- COMPOSITE ----
  vec3 finalColor = bg * 0.6;
  finalColor += rimColor * borderMask;
  // Fresnel contribution to body (subtle edge brightening)
  finalColor += vec3(fresnelGlow * 0.15) * edgeInfluence;
  finalColor = mix(finalColor, finalColor + uGlassColor.rgb * 0.2, uGlassColor.a);
  finalColor = min(finalColor, vec3(1.2));
  
  // ---- ALPHA ----
  float standardBaseAlpha = uBaseAlphaMultiplier * uInteractionIntensity;
  float baseAlpha = (uHasBackground > 0.5) ? 0.7 : standardBaseAlpha;
  float standardEdgeAlpha = uEdgeAlphaMultiplier * mix(0.3, 1.0, uInteractionIntensity);
  float edgeAlpha = (uHasBackground > 0.5) ? 0.95 : standardEdgeAlpha;
  
  float glassAlpha = mix(baseAlpha, edgeAlpha, edgeInfluence);
  // Fresnel boosts edge alpha slightly for that glassy edge catch
  glassAlpha += fresnelTerm * 0.1;
  glassAlpha = max(glassAlpha, borderMask * 0.9);
  float alpha = glassAlpha * mask;
  
  fragColor = vec4(finalColor * alpha, alpha);
}
