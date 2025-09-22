Shader "Class/EnvReflectionBlend"
{
    Properties
    {
        _BaseMap     ("Base Map", 2D) = "white" {}
        _BaseColor   ("Base Color", Color) = (1,1,1,1)
        _EnvCube     ("Environment Cubemap", CUBE) = "" {}
        _EnvIntensity("Env Intensity", Range(0, 4)) = 1
        _EnvBlend    ("Blend (0=Base,1=Env)", Range(0,1)) = 0.5
        _FresnelPow  ("Fresnel Power", Range(0.5, 8)) = 5
        _FresnelBoost("Fresnel Boost", Range(0, 3)) = 1
    }
    SubShader
    {
       
        Pass
        {
            Name "ForwardUnlit"


            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv0        : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS  : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float2 uv          : TEXCOORD2;
            };

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURECUBE(_EnvCube); SAMPLER(sampler_EnvCube);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;
                float  _EnvIntensity;
                float  _EnvBlend;
                float  _FresnelPow;
                float  _FresnelBoost;
            CBUFFER_END

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                float3 posWS    = TransformObjectToWorld(IN.positionOS.xyz);
                float3 nrmWS    = TransformObjectToWorldNormal(IN.normalOS);
                OUT.positionWS  = posWS;
                OUT.normalWS    = nrmWS;
                OUT.positionHCS = TransformWorldToHClip(posWS);
                OUT.uv          = TRANSFORM_TEX(IN.uv0, _BaseMap);
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                half3 N = SafeNormalize(IN.normalWS);
                half3 V = SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));

                // Base
                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half3 baseCol = baseTex.rgb * _BaseColor.rgb;

                // Reflection vector and cubemap sample (slide 76)
                half3 R = reflect(-V, N);
                half3 envRGB = SAMPLE_TEXTURECUBE(_EnvCube, sampler_EnvCube, R).rgb * _EnvIntensity;

                // Optional Fresnel to amplify edge reflections
                half ndotv = saturate(dot(N, V));
                half fres  = pow(1.0h - ndotv, _FresnelPow) * _FresnelBoost;

                // Blend between base and env; push env by Fresnel near edges
                half envWeight = saturate(_EnvBlend + fres * (1.0h - _EnvBlend));
                half3 finalRGB = lerp(baseCol, envRGB, envWeight);

                return half4(finalRGB, baseTex.a * _BaseColor.a);
            }
            ENDHLSL
        }
    }
}
