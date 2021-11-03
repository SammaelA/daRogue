require daslib/media
// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code
let
    NO_HIT = 0
    WALL = 1
    ENEMY = 2
    PLAYER = 3

    BASE_TILE_SIZE = 8
    BASE_PIXEL_SIZE = 8
    manacost = 25.0f
struct Tile
    size_x: int
    size_y: int
    main_color: uint //if content is empty main color is drawn
    content: array<uint>

struct Entity
    alive: bool
    pos: float2
    dir: float2
    max_speed: float
    hp: float
    max_hp: float
    mana: float
    max_mana: float
    missile_dmg: float
    phys_dmg: float
    tile_type: int
    cooldown: float
    id: int

struct Missile
    pos: float2
    dir: float2
    speed: float
    alive: bool
    phys_damage: float
    magic_damage: float
    tile_type: int
    owner_id: int

struct Grenade
    pos: float2
    alive: bool
    phys_damage: float
    tile_type: int
    cooldown: float
struct Map
    size_x: int
    size_y: int
    left_down_corner: float2
    tiles: array<uint>
var
    map: Map
    camera_pos = float2(32,32)
    player: Entity
    enemies: array<Entity>
    missiles: array<Missile>
    grenades: array<Grenade>
    tiles: array<Tile>
    tile_raw_by_name: table<string; int>
    color_by_char: table<int; uint> 
    seed = int4(762, 22, 3, 4)
    entities_cnt = 0
    game_finished = false

def set_content(var content: array<uint>; str: string)
    for c in str
        if (c != '\n')
            var color = color_by_char[c]
            push(content, color)

def load_tiles
    color_by_char['_'] = 0x000000
    color_by_char['#'] = 0xFFFFFF
    color_by_char['*'] = 0xFFFF00
    resize(tiles,16)
    var nothing: Tile
    tiles[0].size_x = BASE_TILE_SIZE
    tiles[0].size_y = BASE_TILE_SIZE
    tiles[0].main_color = 0x000000
    tile_raw_by_name["nothing"] = 0

    tiles[1].size_x = BASE_TILE_SIZE
    tiles[1].size_y = BASE_TILE_SIZE
    tiles[1].main_color = 0x808080
    tile_raw_by_name["floor"] = 1

    tiles[2].size_x = BASE_TILE_SIZE
    tiles[2].size_y = BASE_TILE_SIZE
    tiles[2].main_color = 0x201505
    tile_raw_by_name["wall"] = 2

    tiles[3].size_x = 7
    tiles[3].size_y = BASE_TILE_SIZE
    tiles[3].main_color = 0x050505
    tile_raw_by_name["player_icon"] = 3
    set_content(tiles[3].content,
    "######_##__##_##__##_##__##_######_##_____##_____##_____")

    tiles[4].size_x = 1
    tiles[4].size_y = 1
    tiles[4].main_color = 0xFFFF00
    tile_raw_by_name["basic_missile_icon"] = 4
    set_content(tiles[4].content,
    "_____**__**_____")

    tiles[5].size_x = BASE_TILE_SIZE
    tiles[5].size_y = BASE_TILE_SIZE
    tiles[5].main_color = 0x050505
    tile_raw_by_name["basic_enemy_icon"] = 5
    set_content(tiles[5].content,
    "________ _######__##__##__##__##__##__##__##__##__######_________")
    
    tiles[6].size_x = 3
    tiles[6].size_y = 3
    tiles[6].main_color = 0xFF0000
    tile_raw_by_name["basic_grenade_icon"] = 6
    set_content(tiles[6].content,
    "_____**__**_____")

    tiles[7].size_x = BASE_TILE_SIZE
    tiles[7].size_y = BASE_TILE_SIZE
    tiles[7].main_color = 0x050505
    tile_raw_by_name["archer_enemy_icon"] = 7
    set_content(tiles[7].content,
    "_________######__##______##______####____##______######_________")

def create_map
    map.size_x = 2*16
    map.size_y = 2*16
    resize(map.tiles, map.size_x*map.size_y);
    for i in range(0, map.size_y)
        for j in range(0, map.size_x) 
            map.tiles[i*map.size_x + j] = 2u
    map.left_down_corner = float2(0, 0)

    var rooms : array<int4>//start pos, end pos
    push(rooms, int4(1,1,4,4))
    push(rooms, int4(4,1,10,2))
    push(rooms, int4(10,1,15,14))
    push(rooms, int4(6,13,10,14))
    push(rooms, int4(1,9,6,14))
    for r in rooms
        for i in range(2*r.y,2*r.w)
            for j in range(2*r.x, 2*r.z)
                map.tiles[j*map.size_x + i] = 1u
def spawn_player
    player.alive = true
    player.pos = camera_pos
    player.tile_type = tile_raw_by_name["player_icon"]
    player.max_speed = 10.0f
    player.max_mana = 100.0f
    player.mana = player.max_mana
    player.max_hp = 50.0f
    player.hp = player.max_hp
    player.missile_dmg = 10.0f
    player.phys_dmg = 5.0f
    player.dir = float2(1,0)
    player.id = entities_cnt
    entities_cnt++

def spawn_enemies
    let cnt = 10
    var spawned = 0
    var iter = 0
    while (spawned < cnt && iter < 1000)
        let x_rnd = random_int(seed) % map.size_x
        let y_rnd = random_int(seed) % map.size_y
        if (map.tiles[x_rnd*map.size_x + y_rnd] == 1u)
            var enemy : Entity
            enemy.alive = true
            enemy.pos = map.left_down_corner + float(BASE_TILE_SIZE)*float2(x_rnd,y_rnd)
            enemy.tile_type = tile_raw_by_name["basic_enemy_icon"]
            enemy.max_speed = 8.0f
            enemy.max_hp = 17.5f
            enemy.hp = enemy.max_hp
            enemy.max_mana = 0.0f
            enemy.mana = enemy.max_mana
            enemy.phys_dmg = 10.0f
            enemy.dir = float2(1,0)
            enemy.id = entities_cnt
            entities_cnt++
            push(enemies, enemy)
            spawned++
        iter++
    
    spawned = 0
    iter = 0
    while (spawned < cnt && iter < 1000)
        let x_rnd = random_int(seed) % map.size_x
        let y_rnd = random_int(seed) % map.size_y
        if (map.tiles[x_rnd*map.size_x + y_rnd] == 1u)
            var enemy : Entity
            enemy.alive = true
            enemy.pos = map.left_down_corner + float(BASE_TILE_SIZE)*float2(x_rnd,y_rnd)
            enemy.tile_type = tile_raw_by_name["archer_enemy_icon"]
            enemy.max_speed = 9.0f
            enemy.max_hp = 11.0f
            enemy.hp = enemy.max_hp
            enemy.max_mana = 100.0f
            enemy.mana = enemy.max_mana
            enemy.phys_dmg = 5.0f
            enemy.dir = float2(1,0)
            enemy.id = entities_cnt
            entities_cnt++
            push(enemies, enemy)
            spawned++
        iter++
def render_background
    for i in range(0, map.size_y)
        for j in range(0, map.size_x) 
            var tile_pos = (map.left_down_corner + float(BASE_TILE_SIZE)*float2(i,j))
            render_tile(tiles[map.tiles[i*map.size_x + j]],tile_pos)
    return
def render_tile(tile: Tile; pos: float2)
    var pix_pos = float(BASE_PIXEL_SIZE)*(pos - camera_pos) + float2(0.5*float(get_screen_width()),0.5*float(get_screen_height()))
    var m = int(BASE_PIXEL_SIZE)
    if (int(pix_pos.x) + m*tile.size_x >= 0 && int(pix_pos.y) + m*tile.size_y >= 0 && int(pix_pos.x) < get_screen_width() && int(pix_pos.y) < get_screen_height())
        if (length(tile.content) == 0)
            fill_rect(int(pix_pos.x),int(pix_pos.y),m*tile.size_x, m*tile.size_y, tile.main_color);
        else
            for i in range(0, tile.size_y)
                for j in range(0, tile.size_x)
                    if (tile.content[i*tile.size_x + j] > 0u)
                        fill_rect(int(pix_pos.x) + m*j,int(pix_pos.y) + m*i,
                              m, m, 
                              tile.content[i*tile.size_x + j]);
    return
def render_tile_round(tile: Tile; pos: float2)
    var pix_pos = float(BASE_PIXEL_SIZE)*(pos - camera_pos) + float2(0.5*float(get_screen_width()),0.5*float(get_screen_height()))
    var m = int(BASE_PIXEL_SIZE)
    if (int(pix_pos.x) + m*tile.size_x >= 0 && int(pix_pos.y) + m*tile.size_y >= 0 && int(pix_pos.x) < get_screen_width() && int(pix_pos.y) < get_screen_height())
        fill_circle(int(pix_pos.x),int(pix_pos.y),m*tile.size_x, tile.main_color);
    return

def render_hp_bar(pos: float2; hp_part: float)
    var pix_pos = float(BASE_PIXEL_SIZE)*(pos - camera_pos) + float2(0.5*float(get_screen_width()),0.5*float(get_screen_height()))
    var full_sz = int2(BASE_TILE_SIZE,2)
    var m = int(BASE_PIXEL_SIZE)
    if (int(pix_pos.x) + m*full_sz.x >= 0 && int(pix_pos.y) + m*full_sz.y >= 0 && int(pix_pos.x) < get_screen_width() && int(pix_pos.y) < get_screen_height())
        fill_rect(int(pix_pos.x),int(pix_pos.y) - m*full_sz.y - 2,int(float(m*full_sz.x)*hp_part) + 1, m*full_sz.y, 0xFF0000);

def render_mana_bar(pos: float2; hp_part: float)
    var pix_pos = float(BASE_PIXEL_SIZE)*(pos - camera_pos) + float2(0.5*float(get_screen_width()),0.5*float(get_screen_height()))
    var full_sz = int2(BASE_TILE_SIZE,2)
    var m = int(BASE_PIXEL_SIZE)
    if (int(pix_pos.x) + m*full_sz.x >= 0 && int(pix_pos.y) + m*full_sz.y >= 0 && int(pix_pos.x) < get_screen_width() && int(pix_pos.y) < get_screen_height())
        fill_rect(int(pix_pos.x),int(pix_pos.y) - 2*m*full_sz.y - 2,int(float(m*full_sz.x)*hp_part) + 1, m*full_sz.y, 0x0000FF);

def render_cd_bar(pos: float2; hp_part: float)
    var pix_pos = float(BASE_PIXEL_SIZE)*(pos - camera_pos) + float2(0.5*float(get_screen_width()),0.5*float(get_screen_height()))
    var full_sz = int2(BASE_TILE_SIZE,2)
    var m = int(BASE_PIXEL_SIZE)
    if (int(pix_pos.x) + m*full_sz.x >= 0 && int(pix_pos.y) + m*full_sz.y >= 0 && int(pix_pos.x) < get_screen_width() && int(pix_pos.y) < get_screen_height())
        fill_rect(int(pix_pos.x),int(pix_pos.y) + m*full_sz.x + 2,int(float(m*full_sz.x)*hp_part), int(0.5*float(m)), 0xFFFFFF);

def render_player
    if (player.alive == true)
        render_tile(tiles[player.tile_type],player.pos) 
    render_hp_bar(player.pos, player.hp/player.max_hp)
    render_mana_bar(player.pos, player.mana/player.max_mana)
    render_cd_bar(player.pos, player.cooldown)
def render_missiles
    for m in missiles
        if (m.alive)
            render_tile_round(tiles[m.tile_type],m.pos) 
    for g in grenades
        if (g.alive)
            render_tile_round(tiles[g.tile_type],g.pos) 
            render_cd_bar(g.pos, 0.2*g.cooldown)
def render_entities
    for m in enemies
        if (m.alive)
            render_tile(tiles[m.tile_type],m.pos) 
        render_hp_bar(m.pos, m.hp/m.max_hp)
        render_cd_bar(m.pos, m.cooldown)

def collision_tile(pos: float2; size: float2; tile_pos: float2; tile: Tile): bool
    return (pos.x < tile_pos.x + float(tile.size_x)) && (pos.x + size.x > tile_pos.x) && (pos.y < tile_pos.y + float(tile.size_y)) && (pos.y + size.y > tile_pos.y)
def test_collision(pos: float2; size: float2; id: int): int2
    var map_tile_n = (pos - map.left_down_corner)/float(BASE_TILE_SIZE)
    if (map_tile_n.x < 1.0f || map_tile_n.y < 1.0f || map_tile_n.x >= float(map.size_x - 1) || map_tile_n.y >= float(map.size_y - 1))
        return int2(WALL,0)
    var st = int2(map_tile_n)
    
    for i in range(-1,2)
        for j in range(-1,2)
            let tile_coord = st + int2(i,j)
            let tile = map.tiles[tile_coord.x*map.size_x + tile_coord.y]
            let tile_pos = map.left_down_corner + float(BASE_TILE_SIZE)*float2(tile_coord)
            if (tile != 1u && collision_tile(pos, size, tile_pos, tiles[tile]))
                return int2(WALL, tile_coord.y*map.size_x + tile_coord.x)
    
    var i = 0
    for m in enemies
        if (m.id != id)
            if (collision_tile(pos, size, m.pos, tiles[m.tile_type]))
                return int2(ENEMY,i)
        i++
    if (id != player.id && collision_tile(pos, size, player.pos, tiles[player.tile_type]))
        return int2(PLAYER,0)
    return int2(NO_HIT,0)

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("Test")
    reset()

def reset
    entities_cnt = 0
    camera_pos = float2(32,32)
    game_finished = false
    load_tiles()
    create_map()
    spawn_player()
    spawn_enemies()   

def update_missiles(dt: float)
    var i = 0
    while i < length(missiles)
        if (!missiles[i].alive ||
             missiles[i].pos.x < map.left_down_corner.x ||
             missiles[i].pos.y < map.left_down_corner.y ||
             missiles[i].pos.x > map.left_down_corner.x + float(map.size_x*BASE_TILE_SIZE) ||
             missiles[i].pos.y > map.left_down_corner.y + float(map.size_y*BASE_TILE_SIZE))
            
            erase(missiles,i)
        else
            let hit = test_collision(missiles[i].pos, float2(4,4),missiles[i].owner_id);
            if (hit.x == WALL)
                erase(missiles,i)
            elif (hit.x == ENEMY && missiles[i].owner_id == player.id)
                enemies[hit.y].hp -= missiles[i].phys_damage + missiles[i].magic_damage
                erase(missiles,i)
            elif (hit.x == PLAYER)
                player.hp -= missiles[i].phys_damage + missiles[i].magic_damage
                erase(missiles,i)
            else    
                missiles[i].pos += dt*missiles[i].speed*missiles[i].dir
                i++
def update_grenades(dt: float)
    var i = 0
    while i < length(grenades)
        if (!grenades[i].alive)
            erase(grenades,i)
        grenades[i].cooldown -= dt
        if (grenades[i].cooldown <= 0.0f)
            for en in enemies
                var dist = length(grenades[i].pos - en.pos)
                if (dist < 20.0f)
                    en.hp -= grenades[i].phys_damage
            var dist = length(grenades[i].pos - player.pos)
            if (dist < 20.0f)
                player.hp -= grenades[i].phys_damage
            erase(grenades,i)
        else
            i++
def update_enemies(dt: float)
    var i = 0
    while i < length(enemies)
        if (enemies[i].hp < 0.0f)
            enemies[i].alive = false
        enemies[i].cooldown -= dt
        enemies[i].hp += 1.0f*dt
    
        enemies[i].hp = min(enemies[i].hp, enemies[i].max_hp)
        enemies[i].mana = min(enemies[i].mana, enemies[i].max_mana)
        enemies[i].cooldown = max(enemies[i].cooldown,0.0f)

        if (enemies[i].alive)
            let dist = length(player.pos - enemies[i].pos)
            if (dist <= float(BASE_TILE_SIZE + 1))
                if (enemies[i].cooldown <= 0f)
                    enemies[i].cooldown = 1.0f
                    player.hp -= enemies[i].phys_dmg
            else
                if (dist <= float(6*BASE_TILE_SIZE + 1))
                    enemies[i].dir = normalize(player.pos - enemies[i].pos)
                    if (enemies[i].max_mana > 0f && enemies[i].cooldown <= 0f)
                        enemies[i].dir *= -1.0f
                        if (enemies[i].mana > manacost)
                            enemies[i].mana -= manacost
                            enemies[i].cooldown = 0.5f
                            for j in range(-1,2)
                                var mis : Missile
                                mis.pos = enemies[i].pos
                                mis.dir = -enemies[i].dir + 0.2*float(j)*float2(enemies[i].dir.y, -enemies[i].dir.x)
                                mis.speed = 50.0f
                                mis.alive = true
                                mis.phys_damage = 0.0f
                                mis.magic_damage = 5.0f
                                mis.tile_type = tile_raw_by_name["basic_missile_icon"]
                                mis.owner_id = enemies[i].id
                                push(missiles,mis)

                let prev_pos = enemies[i].pos
                enemies[i].pos += dt*enemies[i].dir
                if (test_collision(enemies[i].pos, float2(tiles[enemies[i].tile_type].size_x, tiles[enemies[i].tile_type].size_y), enemies[i].id).x != NO_HIT)
                    enemies[i].pos = prev_pos
            i++
        else
            erase(enemies,i)

def key_input(dt: float)
    player.alive = player.alive && player.hp > 0.0f
    if (!player.alive)
        return
    player.cooldown -= dt
    player.hp += 1.5f*dt
    player.mana += 3f*dt
    
    player.hp = min(player.hp, player.max_hp)
    player.mana = min(player.mana, player.max_mana)
    player.cooldown = max(player.cooldown,0.0f)

    let prev_pos = player.pos
    if (get_key(VK_D))
        player.pos.x += dt*player.max_speed
        player.dir = float2(1,0)
    if (get_key(VK_A))
        player.pos.x -= dt*player.max_speed
        player.dir = float2(-1,0)
    if (get_key(VK_S))
        player.pos.y += dt*player.max_speed
        player.dir = float2(0,1)
    if (get_key(VK_W))
        player.pos.y -= dt*player.max_speed
        player.dir = float2(0,-1)
    if get_key(VK_SPACE)
        if (player.cooldown <= 0.0f && player.mana >= 2.0f*manacost)
            player.cooldown = 1.5
            player.mana -= 2.0f*manacost
            var mis : Grenade
            mis.pos = player.pos
            mis.alive = true
            mis.phys_damage = 3.0f*player.missile_dmg
            mis.cooldown = 5.0f
            mis.tile_type = tile_raw_by_name["basic_grenade_icon"]
            push(grenades,mis)
    if get_key(VK_E)
        if (player.cooldown <= 0.0f && player.mana >= manacost)
            player.cooldown = 0.75
            player.mana -= manacost
            var mis : Missile
            mis.pos = player.pos
            mis.dir = player.dir
            mis.speed = 50.0f
            mis.alive = true
            mis.phys_damage = 0.0f
            mis.owner_id = player.id
            mis.magic_damage = player.missile_dmg
            mis.tile_type = tile_raw_by_name["basic_missile_icon"]
            push(missiles,mis)
    if get_key(VK_Q)
        if (player.cooldown <= 0.0f)
            player.cooldown = 0.75
            let col = test_collision(player.pos + player.dir, float2(tiles[player.tile_type].size_x, tiles[player.tile_type].size_y), player.id)
            if (col.x == ENEMY)
                enemies[col.y].hp -= player.phys_dmg
    if (test_collision(player.pos, float2(tiles[player.tile_type].size_x, tiles[player.tile_type].size_y), player.id).x != NO_HIT)
        player.pos = prev_pos
// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    key_input(dt)
    camera_pos = player.pos
    if get_key(VK_R) && game_finished
        reset()
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    update_missiles(dt)
    update_grenades(dt)
    update_enemies(dt)
    return

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    render_background()

    if (!player.alive)
        set_font_size(int(0.1f*float(get_screen_height())))
        text_out(int(0.25f*float(get_screen_width())), int(0.4f*float(get_screen_height())), "GAME OVER", 0xFFFF0000)
        game_finished = true
    elif (length(enemies) == 0)
        set_font_size(int(0.1f*float(get_screen_height())))
        text_out(int(0.25f*float(get_screen_width())), int(0.4f*float(get_screen_height())), "YOU WON", 0xFF00FF00)
        game_finished = true
    else 
        render_player()
        render_missiles()
        render_entities()
    return
