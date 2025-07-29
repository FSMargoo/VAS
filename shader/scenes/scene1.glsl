#version 330 core

in vec2 vUV;
out vec4 FragColor;

uniform float iTime;

#define PI      3.1415926
#define TWO_PI  6.28318530718
#define EPSILON 0.0001
#define MAX(T, P1, P2) if (theta < T) { R1 = P1; R2 = P2; theta = T; }

struct BoxData {
    vec2 LeftTop;
    vec2 RightBottom;
};

struct TriangleData {
    vec2 P1;
    vec2 P2;
    vec2 P3;
};

///////////////////////////////////////////////////
// The SDF of a box
//
float SDFBox(in vec2 Point, in BoxData Box) {
    vec2 center       = (Box.RightBottom + Box.LeftTop) / 2.0f;
    vec2 relatedPoint = Point - center;
    vec2 box          = (Box.RightBottom - Box.LeftTop) / 2.0f;

    vec2 d = abs(relatedPoint) - box;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

///////////////////////////////////////////////////
// The SDF of a triangle
//
float SDFTriangle(in vec2 p, in TriangleData Triangle)
{
    vec2 p0 = Triangle.P1;
    vec2 p1 = Triangle.P2;
    vec2 p2 = Triangle.P3;

    vec2 e0 = p1-p0, e1 = p2-p1, e2 = p0-p2;
    vec2 v0 = p -p0, v1 = p -p1, v2 = p -p2;
    vec2 pq0 = v0 - e0*clamp( dot(v0,e0)/dot(e0,e0), 0.0, 1.0 );
    vec2 pq1 = v1 - e1*clamp( dot(v1,e1)/dot(e1,e1), 0.0, 1.0 );
    vec2 pq2 = v2 - e2*clamp( dot(v2,e2)/dot(e2,e2), 0.0, 1.0 );
    float s = sign( e0.x*e2.y - e0.y*e2.x );
    vec2 d = min(min(vec2(dot(pq0,pq0), s*(v0.x*e0.y-v0.y*e0.x)),
                     vec2(dot(pq1,pq1), s*(v1.x*e1.y-v1.y*e1.x))),
                     vec2(dot(pq2,pq2), s*(v2.x*e2.y-v2.y*e2.x)));
    return -sqrt(d.x)*sign(d.y);
}

///////////////////////////////////////////////////
// Calculate the angel of the rectangle
//
float AngleBox(in vec2 Point, in BoxData Box) {
    vec2 center = (Box.RightBottom + Box.LeftTop) / 2.0f;
    vec2 uv     = abs(Point - center);
    vec2 box    = (Box.RightBottom - Box.LeftTop) / 2.0f;

    vec2 v1 = uv - vec2(box.x * sign(box.y - uv.y), box.y);
    vec2 v2 = uv - vec2(box.x, box.y * sign(box.x - uv.x));

    return acos(dot(normalize(v1), normalize(v2)));
}
///////////////////////////////////////////////////
// Calculate the angel of the triangle
//
float AngleTriangle(in vec2 P, in TriangleData Triangle) {
    vec2 A = Triangle.P1;
    vec2 B = Triangle.P2;
    vec2 C = Triangle.P3;

    vec2 PA = normalize(A - P);
    vec2 PB = normalize(B - P);
    vec2 PC = normalize(C - P);

    float theta1 = acos(dot(PA, PB));
    float theta2 = acos(dot(PA, PC));
    float theta3 = acos(dot(PB, PC));

    float theta = theta1;
    vec2 R1 = A;
    vec2 R2 = B;

    MAX(theta2, A, C);
    MAX(theta3, B, C);

    return acos(dot(normalize(R1 - P), normalize(R2 - P)));
}

///////////////////////////////////////////////////
// Converting a vector in vec2 format into a radi-
// an value between [0, 2PI)
//
float AngleFromVec2(vec2 Vector) {
    float a = atan(Vector.y, Vector.x);
    return mod(a + TWO_PI, TWO_PI);
}

///////////////////////////////////////////////////
// Gets the starting and ending angles of
// the minor arc connecting two points P1 and P2.
//
void GetMinorArcAngles(vec2 P1, vec2 P2, out float StartAngle, out float EndAngle) {
    float angleP1 = AngleFromVec2(P1);
    float angleP2 = AngleFromVec2(P2);

    float diff = mod(angleP2 - angleP1 + TWO_PI, TWO_PI);

    if (diff <= PI + EPSILON) {
        StartAngle = angleP1;
        EndAngle   = angleP2;
    } else {
        StartAngle = angleP2;
        EndAngle   = angleP1;
    }
}

///////////////////////////////////////////////////
// Determine whether a test angle inside a given
// angle range
//
bool IsAngleInArc(float Angel, float Start, float End, float Epsilon) {
    if (Start <= End + Epsilon) {
        return Angel >= Start - Epsilon && Angel <= End + Epsilon;
    } else {
        return Angel >= Start - Epsilon || Angel <= End + Epsilon;
    }
}

///////////////////////////////////////////////////
// Determine whether the minor arc AB overlaps
// with the minor arc CD.
//
bool DoMinorArcsOverlap(vec2 A, vec2 B, vec2 C, vec2 D) {
    float As, Ae;
    float Cs, Ce;

    GetMinorArcAngles(A, B, As, Ae);
    GetMinorArcAngles(C, D, Cs, Ce);

    if (IsAngleInArc(As, Cs, Ce, EPSILON) || IsAngleInArc(Ae, Cs, Ce, EPSILON)) {
        return true;
    }
    if (IsAngleInArc(Cs, As, Ae, EPSILON) || IsAngleInArc(Ce, As, Ae, EPSILON)) {
        return true;
    }

    return false;
}

///////////////////////////////////////////////////
// Calculate the radian angle of the overlap of
// two minor arcs.
//
float GetMinorArcsOverlapAngle(vec2 A, vec2 B, vec2 C, vec2 D) {
    float As, Ae;
    float Cs, Ce;

    GetMinorArcAngles(A, B, As, Ae);
    GetMinorArcAngles(C, D, Cs, Ce);

    float angles[4];
    angles[0] = As;
    angles[1] = Ae;
    angles[2] = Cs;
    angles[3] = Ce;

    if (As <= Ae + EPSILON && Cs <= Ce + EPSILON) {
        float overlapStart = max(As, Cs);
        float overlapEnd = min(Ae, Ce);
        if (overlapEnd > overlapStart + EPSILON) {
            return overlapEnd - overlapStart;
        } else {
            return 0.0;
        }
    }

    vec2 ab_seg1_s_e = vec2(As, Ae);
    vec2 ab_seg2_s_e = vec2(-1.0, -1.0);

    if (As > Ae + EPSILON) {
        ab_seg1_s_e = vec2(As, TWO_PI);
        ab_seg2_s_e = vec2(0.0, Ae);
    }

    vec2 cd_seg1_s_e = vec2(Cs, Ce);
    vec2 cd_seg2_s_e = vec2(-1.0, -1.0);

    if (Cs > Ce + EPSILON) {
        cd_seg1_s_e = vec2(Cs, TWO_PI);
        cd_seg2_s_e = vec2(0.0, Ce);
    }

    float totalOverlapAngle = 0.0;
    float currentOverlapStart, currentOverlapEnd;

    currentOverlapStart = max(ab_seg1_s_e.x, cd_seg1_s_e.x);
    currentOverlapEnd = min(ab_seg1_s_e.y, cd_seg1_s_e.y);
    if (currentOverlapEnd > currentOverlapStart + EPSILON) {
        totalOverlapAngle += (currentOverlapEnd - currentOverlapStart);
    }

    if (cd_seg2_s_e.x >= 0.0) {
        currentOverlapStart = max(ab_seg1_s_e.x, cd_seg2_s_e.x);
        currentOverlapEnd = min(ab_seg1_s_e.y, cd_seg2_s_e.y);
        if (currentOverlapEnd > currentOverlapStart + EPSILON) {
            totalOverlapAngle += (currentOverlapEnd - currentOverlapStart);
        }
    }

    if (ab_seg2_s_e.x >= 0.0) {
        currentOverlapStart = max(ab_seg2_s_e.x, cd_seg1_s_e.x);
        currentOverlapEnd = min(ab_seg2_s_e.y, cd_seg1_s_e.y);
        if (currentOverlapEnd > currentOverlapStart + EPSILON) {
            totalOverlapAngle += (currentOverlapEnd - currentOverlapStart);
        }
    }

    if (ab_seg2_s_e.x >= 0.0 && cd_seg2_s_e.x >= 0.0) {
        currentOverlapStart = max(ab_seg2_s_e.x, cd_seg2_s_e.x);
        currentOverlapEnd = min(ab_seg2_s_e.y, cd_seg2_s_e.y);
        if (currentOverlapEnd > currentOverlapStart + EPSILON) {
            totalOverlapAngle += (currentOverlapEnd - currentOverlapStart);
        }
    }

    return totalOverlapAngle;
}

///////////////////////////////////////////////////
// Finding two points that could frame a rectangle
//
vec4 GetFramingPointsRectangle(vec2 P, BoxData Box) {
    vec2 A = Box.LeftTop;
    vec2 B = vec2(Box.RightBottom.x, Box.LeftTop.y);
    vec2 C = vec2(Box.LeftTop.x, Box.RightBottom.y);
    vec2 D = Box.RightBottom;

    vec2 PA = normalize(A - P);
    vec2 PB = normalize(B - P);
    vec2 PC = normalize(C - P);
    vec2 PD = normalize(D - P);

    float theta1 = acos(dot(PA, PB));
    float theta2 = acos(dot(PA, PC));
    float theta3 = acos(dot(PA, PD));
    float theta4 = acos(dot(PB, PC));
    float theta5 = acos(dot(PB, PD));
    float theta6 = acos(dot(PC, PD));

    float theta = theta1;
    vec2 R1 = A;
    vec2 R2 = B;

    MAX(theta2, A, C);
    MAX(theta3, A, D);
    MAX(theta4, B, C);
    MAX(theta5, B, D);
    MAX(theta6, C, D);

    return vec4(normalize(R1 - P), normalize(R2 - P));
}

///////////////////////////////////////////////////
// Finding two points that could frame a triangle
//
vec4 GetFramingPointsTriangle(vec2 P, TriangleData Triangle) {
    vec2 A = Triangle.P1;
    vec2 B = Triangle.P2;
    vec2 C = Triangle.P3;

    vec2 PA = normalize(A - P);
    vec2 PB = normalize(B - P);
    vec2 PC = normalize(C - P);

    float theta1 = acos(dot(PA, PB));
    float theta2 = acos(dot(PA, PC));
    float theta3 = acos(dot(PB, PC));

    float theta = theta1;
    vec2 R1 = A;
    vec2 R2 = B;

    MAX(theta2, A, C);
    MAX(theta3, B, C);

    return vec4(normalize(R1 - P), normalize(R2 - P));
}

struct RectangleLight {
    BoxData Data;
    vec3          Color;
};
struct TriangleLight {
    TriangleData Data;
    vec3         Color;
};

void main() {
    vec2 uv = vUV;
    uv.y = 1.0 - uv.y;

    TriangleData   triangleBlock;
    BoxData        rectangleBlock;
    RectangleLight rectangleLight;
    TriangleLight  triangleLight;

    rectangleLight.Data.LeftTop     = vec2(0.2, 0.2 + 0.2f * sin(iTime));
    rectangleLight.Data.RightBottom = rectangleLight.Data.LeftTop + vec2(0.1, 0.4);
    rectangleLight.Color            = vec3(0.03529411764705882, 0.24705882352941178, 0.7058823529411765) + vec3(0.6f);

    triangleLight.Data.P1 = vec2(0.8, 0.2);
    triangleLight.Data.P2 = vec2(0.7, 0.4);
    triangleLight.Data.P3 = vec2(0.9, 0.5);
    triangleLight.Color   = vec3(0.9294117647058824, 0.20784313725490197, 0.0);

    rectangleBlock.LeftTop     = vec2(0.6, 0.5);
    rectangleBlock.RightBottom = vec2(0.7, 0.6);

    triangleBlock.P1 = vec2(0.4, 0.2);
    triangleBlock.P2 = vec2(0.55, 0.3);
    triangleBlock.P3 = vec2(0.65, 0.25);

    vec3 color = vec3(0.0);
    do {
    float rectLightD = SDFBox(uv, rectangleLight.Data);
    float triLightD  = SDFTriangle(uv, triangleLight.Data);
    float boxBlockD  = SDFBox(uv, rectangleBlock);
    float triBlockD  = SDFTriangle(uv, triangleBlock);

    if (rectLightD <= 0.0) { color = rectangleLight.Color; break; }
    if (triLightD <= 0.0) { color = triangleLight.Color; break; }
    if (boxBlockD <= 0.0) { color = vec3(0.0); break; }
    if (triBlockD <= 0.0) { color = vec3(0.0); break; }

    // Process the rectangle light
    {
        float theta = AngleBox(uv, rectangleLight.Data);
        if (rectLightD > boxBlockD) {
            vec4 blockSet = GetFramingPointsRectangle(uv, rectangleBlock);
            vec4 lightSet = GetFramingPointsRectangle(uv, rectangleLight.Data);

            vec2 lv1 = lightSet.xy;
            vec2 lv2 = lightSet.zw;

            vec2 v1 = blockSet.xy;
            vec2 v2 = blockSet.zw;

            if (DoMinorArcsOverlap(lv1, lv2, v1, v2)) {
                theta -= GetMinorArcsOverlapAngle(lv1, lv2, v1, v2);
            }
        }
        if (rectLightD > triBlockD) {
            vec4 blockSet = GetFramingPointsTriangle(uv, triangleBlock);
            vec4 lightSet = GetFramingPointsRectangle(uv, rectangleLight.Data);

            vec2 lv1 = lightSet.xy;
            vec2 lv2 = lightSet.zw;

            vec2 v1 = blockSet.xy;
            vec2 v2 = blockSet.zw;

            if (DoMinorArcsOverlap(lv1, lv2, v1, v2)) {
                theta -= GetMinorArcsOverlapAngle(lv1, lv2, v1, v2);
            }
        }

        color += rectangleLight.Color * (theta / (2 * PI));
    } while(false);

    // Process the triangle light
    {
        float theta = AngleTriangle(uv, triangleLight.Data);
        if (triLightD > boxBlockD) {
            vec4 blockSet = GetFramingPointsRectangle(uv, rectangleBlock);
            vec4 lightSet = GetFramingPointsTriangle(uv, triangleLight.Data);

            vec2 lv1 = lightSet.xy;
            vec2 lv2 = lightSet.zw;

            vec2 v1 = blockSet.xy;
            vec2 v2 = blockSet.zw;

            if (DoMinorArcsOverlap(lv1, lv2, v1, v2)) {
                theta -= GetMinorArcsOverlapAngle(lv1, lv2, v1, v2);
            }
        }
        if (triLightD > triBlockD) {
            vec4 blockSet = GetFramingPointsTriangle(uv, triangleBlock);
            vec4 lightSet = GetFramingPointsTriangle(uv, triangleLight.Data);

            vec2 lv1 = lightSet.xy;
            vec2 lv2 = lightSet.zw;

            vec2 v1 = blockSet.xy;
            vec2 v2 = blockSet.zw;

            if (DoMinorArcsOverlap(lv1, lv2, v1, v2)) {
                theta -= GetMinorArcsOverlapAngle(lv1, lv2, v1, v2);
            }
        }

        color += triangleLight.Color * (theta / (2 * PI));
    } while(false);
    } while(false);

    FragColor = vec4(color, 1.0) * 2.0;
}