package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Vector :: [3] f32

Model :: rl.Model
Color :: rl.Color
Mesh  :: rl.Mesh

lighting_shader: rl.Shader
lighting_shader_camera: i32

main :: proc() {
    using rl

    SetConfigFlags({ .WINDOW_RESIZABLE })
    InitWindow(1280, 720, "hourglass demo")
    SetTargetFPS(60)
    
    camera: Camera = {
        projection = .PERSPECTIVE,
        position   = { 8, 2, 8 },
        target     = { 0, 1, 0 },
        up         = { 0, 1, 0 },
        fovy       =          45,
    }

    // camera: Camera = {
    //     projection = .ORTHOGRAPHIC, // .PERSPECTIVE,
    //     position   = { 8, 0, 0.0001 },
    //     target     = { 0, 0, 0 },
    //     up         = { 0, 1, 0 },
    //     fovy       = 30,
    // }

    the_model := make_model()
    hourglass := make_hourglass()

    rl.DisableCursor()
    for !WindowShouldClose() {
        BeginDrawing()
        defer EndDrawing()
        rl.ClearBackground({ 20, 20, 20, 255 })
        // rl.ClearBackground(rl.WHITE)

        rl.UpdateCamera(&camera, .FREE)
    
        BeginMode3D(camera)
        defer EndMode3D()

        rl.SetShaderValue(lighting_shader, lighting_shader_camera, &camera.position, .VEC3)
        
        rl.DrawModel(the_model, {}, 1, rl.WHITE)
        rl.DrawModel(hourglass, {}, 1, rl.WHITE)
    }
}

make_model :: proc() -> Model {// {{{
    using rl

    lighting_shader = rl.LoadShaderFromMemory(DIFFUSE_VERTEX_SHADER, DIFFUSE_FRAGMENT_SHADER)
    assert(rl.IsShaderValid(lighting_shader))

    lighting_shader_camera = rl.GetShaderLocation(lighting_shader, "camera")

    model: Model
    model.transform = 1
    model.materialCount = 1

    model.meshes = make([^]Mesh, 1024 * 16)
    model.meshMaterial = make([^]i32, 1024 * 16)
    model.materials = make([^]Material, 8)
    model.materials[0] = rl.LoadMaterialDefault()
    model.materials[0].shader = lighting_shader
        
    // smėlio laikrodžio pagrindas + viršus
    new_mesh(&model)^ = move(rl.GenMeshCylinder(1,   0.3, 15), { 0, 2.71, 0 })
    new_mesh(&model)^ = move(rl.GenMeshCylinder(1,   0.3, 15), { 0,    0, 0 })

    // smėlio laikrodžio stulpeliai
    new_mesh(&model)^ = move(rl.GenMeshCylinder(0.05, 3, 15), { 0, 0,  0.9 })
    new_mesh(&model)^ = move(rl.GenMeshCylinder(0.05, 3, 15), { 0, 0, -0.9 })
    new_mesh(&model)^ = move(rl.GenMeshCylinder(0.05, 3, 15), {  0.9, 0, 0 })
    new_mesh(&model)^ = move(rl.GenMeshCylinder(0.05, 3, 15), { -0.9, 0, 0 })

    // stalas
    new_mesh(&model)^ = move(rl.GenMeshCube(12, 0.6, 18), {  0, -0.3,  0 })
    new_mesh(&model)^ = move(rl.GenMeshCube(0.8, 5, 0.8), {  5, -2.6,  8 })
    new_mesh(&model)^ = move(rl.GenMeshCube(0.8, 5, 0.8), { -5, -2.6, -8 })
    new_mesh(&model)^ = move(rl.GenMeshCube(0.8, 5, 0.8), { -5, -2.6,  8 })
    new_mesh(&model)^ = move(rl.GenMeshCube(0.8, 5, 0.8), {  5, -2.6, -8 })

    new_mesh(&model)^ = move(rl.GenMeshCube(6, 6, 2.5),  {  0, 3, 6 })

    // monitorius
    rot := linalg.matrix3_rotate_f32(math.PI/20, { 0, 1, 0 })
    new_mesh(&model)^ = move(rotate(rl.GenMeshCube(0.5, 5, 10), rot), { -3, 5, -2 })
    new_mesh(&model)^ = move(rotate(rl.GenMeshCube(0.5, 2.5, 2), rot),  { -3, 1.25, -2 })
    new_mesh(&model)^ = move(rotate(rl.GenMeshCone(3, 0.5, 5), rot),  { -3, 0, -2 })
    
    // HDMI laidas
    rot = linalg.matrix3_rotate_f32(-math.PI/40, { 0, 1, 0 })
    new_mesh(&model)^ = move(rl.GenMeshCube(0.2, 2, 0.2), { -3.1, 1.5, 5.7 })
    new_mesh(&model)^ = move(rotate(rl.GenMeshCube(0.2, 0.2, 4), rot), { -3.3, 0.5, 3.8 })
    new_mesh(&model)^ = move(rl.GenMeshCube(0.2, 3, 0.2), { -3.5, 1.9, 1.7 })
    // kiti laidai...
    new_mesh(&model)^ = move(rl.GenMeshCube(0.2, 5, 0.2), { -3.1, 2.5, 6 })
    new_mesh(&model)^ = move(rl.GenMeshCube(0.2, 4, 0.2), { -3.1, 2.0, 5.1 })

    for &mesh in model.meshes[:model.meshCount] {
        vertices  := (cast([^]Vector) mesh.texcoords)[:mesh.vertexCount]
        size: Vector
        for v in vertices {
            size.x = max(size.x, v.x)
            size.y = max(size.y, v.y)
            size.z = max(size.z, v.z)
        }

        texcoords := (cast([^][2]f32) mesh.texcoords)[:mesh.vertexCount]
        for i in 0..<mesh.vertexCount { texcoords[i] *= linalg.length(size) }
        rl.UpdateMeshBuffer(mesh, 1, raw_data(texcoords), mesh.vertexCount * 2 * size_of(f32), 0)
    }

    return model
}// }}}

make_hourglass :: proc() -> Model {// {{{
    using rl
    hourglass_shader := rl.LoadShaderFromMemory(HOURGLASS_VERTEX_SHADER, HOURGLASS_FRAGMENT_SHADER)
    assert(rl.IsShaderValid(hourglass_shader))

    model: Model
    model.transform = auto_cast linalg.matrix4_scale_f32({ 1, 3, 1 })
    model.materialCount = 1

    model.meshes = make([^]Mesh, 1024 * 16)
    model.meshMaterial = make([^]i32, 1024 * 16)
    model.materials = make([^]Material, 8)
    model.materials[0] = rl.LoadMaterialDefault()
    model.materials[0].shader = hourglass_shader
    
    new_mesh(&model)^ = rl.GenMeshCylinder(1, 1, 15)

    return model
}// }}}

// "translate mesh"
rotate :: proc(mesh: Mesh, by: linalg.Matrix3f32) -> Mesh {
    vertices := (cast([^]Vector) mesh.vertices)[:mesh.vertexCount]
    for &vertex in vertices { vertex *= by }
    rl.UpdateMeshBuffer(mesh, 0, raw_data(vertices), mesh.vertexCount * 3 * size_of(f32), 0)
    return mesh
}

// "translate mesh"
move :: proc(mesh: Mesh, pos: Vector) -> Mesh {
    vertices := (cast([^]Vector) mesh.vertices)[:mesh.vertexCount]
    for &vertex in vertices { vertex += pos }
    rl.UpdateMeshBuffer(mesh, 0, raw_data(vertices), mesh.vertexCount * 3 * size_of(f32), 0)
    return mesh
}

new_mesh :: proc(model: ^Model) -> ^Mesh { 
    defer model.meshCount += 1 
    return &model.meshes[model.meshCount] 
}

//{{{
DIFFUSE_FRAGMENT_SHADER :: `
#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;
flat in vec2 flatTexCoord;

out vec4 finalColor;

uniform vec3 camera;

void main() {
    vec3 light  = vec3(.25, .5,  .33);
    vec3 albedo = vec3(.15, .15, .15); // neprisimenu ar tikrai tas žodis, mažiausia įmanoma šviesa, veiktų ir „ambient“
    
    finalColor = fragColor;
    float lux  = max(dot(fragNormal, light), 0.);
    finalColor.rgb *= lux;
    finalColor.rgb = max(finalColor.rgb, albedo);
    
    vec3 view = camera - fragPosition;

    vec2  tc = fragTexCoord;
    // float l1 = exp(1. / length(view)       ) / 30.;
    // float l2 = 1. - exp(1. / length(view)  ) / 30.;
    float l1 = 0.01;
    float l2x = flatTexCoord.x - l1; if(flatTexCoord.x < .01) l2x = 10000.;
    float l2y = flatTexCoord.y - l1; if(flatTexCoord.y < .01) l2y = 10000.;
    if(tc.x < l1 || tc.y < l1 || tc.x > l2x || tc.y > l2y) {
        finalColor.rgb *= 1.5;
    }

    finalColor.rgb += (10. - fragPosition.x) / 50.;

    // finalColor = vec4((fragNormal + 1) / 2., 1.0);
}
`

DIFFUSE_VERTEX_SHADER :: `
#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;

out vec3 fragPosition;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragNormal;

flat out vec2 flatTexCoord;

#define pi 3.1415926535f

void main() {
    fragPosition = vertexPosition;
    fragTexCoord = vertexTexCoord;
    flatTexCoord = vertexTexCoord;
    fragColor    = vertexColor;
    fragNormal   = normalize(vertexNormal);

    vec3 position = vertexPosition;
    // position.y += sin(length((mvp * vec4(position, 1.0)).xz) * pi) / 2.;
    gl_Position = mvp * vec4(position, 1.0);
}
`
//}}}

//{{{
HOURGLASS_FRAGMENT_SHADER :: `
#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;

// uniform sampler2D texture0; DEFAULT

out vec4 finalColor;

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec3 light  = vec3(.25, .5,  .33);
    vec3 albedo = vec3(.15, .15, .15); // neprisimenu ar tikrai tas žodis, mažiausia įmanoma šviesa, veiktų ir „ambient“
    finalColor  = fragColor;

    float opacity = .2;

    float debrisFreq = smoothstep(.5, .0, fragPosition.y);
    if(rand(floor(fragPosition.xz*100.)/100.) < debrisFreq) {
        finalColor.rgb = vec3(0.9, 0.9, 0.3);
        opacity = .8;
    }

    float lux  = max(dot(fragNormal, light), 0.);
    finalColor.rgb *= lux;
    finalColor.rgb = max(finalColor.rgb, albedo);
    
    // finalColor = vec4((fragNormal + 1) / 2., 1.0);

    finalColor.a = opacity;
}
`

HOURGLASS_VERTEX_SHADER :: `
#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;

out vec3 fragPosition;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragNormal;

#define pi 3.1415926535f

void main() {
    vec3 position = vertexPosition;
    vec3 normal   = vertexNormal;

    if(position.y > 0. && position.y < 1.) {
        vec2  direction = normalize(position.xz);
        float value     = abs(sin(position.y * pi + pi/2.)*.8) + .1;
        float radius    = length(position.xz) * value;
        position.xz     = direction * radius;

        float deltaValue = abs(sin((position.y - 0.01) * pi + pi/2.)*.8) + .1;
        vec2  tangent = normalize(vec2( 0.01, -1. * (value - deltaValue) ));
        normal.y = tangent.y * 1./( length(normal.xz) / tangent.x );
    }

    fragPosition = position;
    fragTexCoord = vertexTexCoord;
    fragColor    = vertexColor;
    fragNormal   = normalize(normal);

    gl_Position = mvp * vec4(position, 1.0);
}
`
//}}}

