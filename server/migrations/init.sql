-- KittyKitty 数据库初始化 (PostgreSQL + PostGIS)
-- 规模化期使用，验证期用 CloudBase MongoDB

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 用户表
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) UNIQUE,
    wechat_openid VARCHAR(64) UNIQUE,
    nickname VARCHAR(50),
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 用户会话
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    token TEXT NOT NULL UNIQUE,
    refresh_token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 短信日志
CREATE TABLE sms_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) NOT NULL,
    code VARCHAR(10) NOT NULL,
    purpose VARCHAR(20) NOT NULL DEFAULT 'login',
    used BOOLEAN DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 猫咪表
CREATE TABLE cats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    cat_face_id UUID REFERENCES cat_faces(id),
    name VARCHAR(50) NOT NULL,
    rarity VARCHAR(20) NOT NULL,
    type VARCHAR(20) NOT NULL,
    base_hp INTEGER NOT NULL,
    base_atk INTEGER NOT NULL,
    base_def INTEGER NOT NULL,
    base_spd INTEGER NOT NULL,
    base_crit DOUBLE PRECISION NOT NULL,
    battle_skills JSONB DEFAULT '[]',
    life_skills JSONB DEFAULT '[]',
    level INTEGER DEFAULT 1,
    exp INTEGER DEFAULT 0,
    image_url TEXT NOT NULL,
    card_image_url TEXT,
    capture_location GEOGRAPHY(POINT, 4326) NOT NULL,
    capture_address TEXT,
    total_battles INTEGER DEFAULT 0,
    total_wins INTEGER DEFAULT 0,
    captured_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cats_user ON cats(user_id);
CREATE INDEX idx_cats_cat_face ON cats(cat_face_id);
CREATE INDEX idx_cats_location ON cats USING GIST(capture_location);
CREATE INDEX idx_cats_rarity ON cats(rarity);

-- 猫脸识别表
CREATE TABLE cat_faces (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    feature_vector vector(512),
    image_url TEXT,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 猫咪目击记录
CREATE TABLE cat_sightings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cat_face_id UUID REFERENCES cat_faces(id),
    user_id UUID NOT NULL REFERENCES users(id),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    image_url TEXT,
    captured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sightings_location ON cat_sightings USING GIST(location);
CREATE INDEX idx_sightings_cat_face ON cat_sightings(cat_face_id);
