package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Vector :: [3] f32

Model :: rl.Model
Color :: rl.Color
Mesh  :: rl.Mesh

main :: proc() {
    using rl

    SetConfigFlags({ .WINDOW_RESIZABLE })
    InitWindow(1280, 720, "hourglass demo")
    SetTargetFPS(60)
    
    camera: Camera = {
        projection = .PERSPECTIVE,
        position   = { 1, 2, 2 },
        target     = { 0, 1, 0 },
        up         = { 0, 1, 0 },
        fovy       =          45,
    }

    the_model := make_model()
    hourglass := make_hourglass()

    rl.DisableCursor()
    for !WindowShouldClose() {
        BeginDrawing()
        defer EndDrawing()
        rl.ClearBackground({ 20, 20, 20, 255 })

        rl.UpdateCamera(&camera, .FREE)
    
        BeginMode3D(camera)
        defer EndMode3D()
    
        rl.DrawModel(hourglass, {}, 1, rl.WHITE)
        rl.DrawModel(the_model, {}, 1, rl.WHITE)
        // rl.DrawCubeV({  }, { 1, 1, 1 }, rl.YELLOW)
        
        rl.DrawGrid(128, 1)

    }

}

make_model :: proc() -> Model {
    using rl


    lighting_shader := rl.LoadShaderFromMemory(DIFFUSE_VERTEX_SHADER, DIFFUSE_FRAGMENT_SHADER)
    assert(rl.IsShaderValid(lighting_shader))

    model: Model
    model.transform = 1
    model.materialCount = 1

    model.meshes = make([^]Mesh, 1024 * 16)
    model.meshMaterial = make([^]i32, 1024 * 16)
    model.materials = make([^]Material, 8)
    model.materials[0] = rl.LoadMaterialDefault()
    model.materials[0].shader = lighting_shader
        
    new_mesh(&model)^ = move(rl.GenMeshCylinder(1,   0.3, 15), { 0, 2.7, 0 })
    // new_mesh(&model)^ = move(rl.GenMeshCylinder(0.6, 0.2, 15), { 0, 1.4, 0 })
    new_mesh(&model)^ = move(rl.GenMeshCylinder(1,   0.3, 15), { 0,   0, 0 })

    new_mesh(&model)^ = move(rl.GenMeshCylinder(0.05, 3, 15), { 0, 0,  0.9 })
    new_mesh(&model)^ = move(rl.GenMeshCylinder(0.05, 3, 15), { 0, 0, -0.9 })
    new_mesh(&model)^ = move(rl.GenMeshCylinder(0.05, 3, 15), {  0.9, 0, 0 })
    new_mesh(&model)^ = move(rl.GenMeshCylinder(0.05, 3, 15), { -0.9, 0, 0 })

    new_mesh(&model)^ = move(rl.GenMeshCube(12, 0.6, 18), {  0, -0.3,  0 })
    new_mesh(&model)^ = move(rl.GenMeshCube(0.8, 5, 0.8), {  5, -2.6,  8 })
    new_mesh(&model)^ = move(rl.GenMeshCube(0.8, 5, 0.8), { -5, -2.6, -8 })
    new_mesh(&model)^ = move(rl.GenMeshCube(0.8, 5, 0.8), { -5, -2.6,  8 })
    new_mesh(&model)^ = move(rl.GenMeshCube(0.8, 5, 0.8), {  5, -2.6, -8 })

    return model
}

// "translate mesh"
move :: proc(mesh: Mesh, pos: Vector) -> Mesh {
    vertices := (cast([^]Vector) mesh.vertices)[:mesh.vertexCount]
    for &vertex in vertices { vertex += pos }
    rl.UpdateMeshBuffer(mesh, 0, raw_data(vertices), mesh.vertexCount * 3 * size_of(f32), 0)
    return mesh
}


make_hourglass :: proc() -> Model {
    using rl
    hourglass_shader := rl.LoadShaderFromMemory(HOURGLASS_VERTEX_SHADER, DIFFUSE_FRAGMENT_SHADER)
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
}

new_mesh :: proc(model: ^Model) -> ^Mesh { 
    defer model.meshCount += 1 
    return &model.meshes[model.meshCount] 
}

DIFFUSE_FRAGMENT_SHADER :: `
#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;

// uniform sampler2D texture0; DEFAULT

out vec4 finalColor;


void main() {
    vec3 light  = vec3(.25, .5,  .33);
    vec3 albedo = vec3(.15, .15, .15); // neprisimenu ar tikrai tas žodis, mažiausia įmanoma šviesa, veiktų ir „ambient“
    
    finalColor = fragColor;
    float lux  = max(dot(fragNormal, light), 0.);
    finalColor.rgb *= lux;
    finalColor.rgb = max(finalColor.rgb, albedo);
}
`


// mažesnė versija iš pavyzdžių, bet šita dalis visada* būna panaši
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

#define pi 3.1415926535f

void main() {
    fragPosition = vertexPosition;
    fragTexCoord = vertexTexCoord;
    fragColor    = vertexColor;
    fragNormal   = normalize(vertexNormal);

    gl_Position = mvp * vec4(vertexPosition, 1.0);
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

    if(position.y > 0. && position.y < 1.) {
        vec2  direction = normalize(position.xz);
        float value     = abs(sin(position.y * pi + pi/2.)*.8) + .1;
        float radius    = length(position.xz) * value;
        position.xz     = direction * radius;

        // vec2 tangent = 
    }

    fragPosition = position;
    fragTexCoord = vertexTexCoord;
    fragColor    = vertexColor;
    fragNormal   = normalize(vertexNormal);

    gl_Position = mvp * vec4(position, 1.0);
}
`

