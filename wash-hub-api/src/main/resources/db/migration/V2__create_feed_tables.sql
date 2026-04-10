-- V2: 피드 관련 테이블 생성
-- Feature: P1-004-feed

CREATE TABLE tb_feed (
    feed_id           BIGINT        NOT NULL AUTO_INCREMENT,
    member_id         BIGINT        NOT NULL,
    content           TEXT          NULL,
    thumbnail_url     VARCHAR(500)  NULL COMMENT 'Before|After 합성 썸네일',
    wash_location     VARCHAR(100)  NULL COMMENT '세차 장소',
    like_count        INT           NOT NULL DEFAULT 0,
    comment_count     INT           NOT NULL DEFAULT 0,
    status            VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE' COMMENT 'ACTIVE, DELETED',
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (feed_id),
    INDEX idx_member_id (member_id),
    INDEX idx_created_at (created_at DESC),
    INDEX idx_like_count (like_count DESC),
    CONSTRAINT fk_feed_member
        FOREIGN KEY (member_id) REFERENCES tb_member (member_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tb_feed_image (
    feed_image_id     BIGINT        NOT NULL AUTO_INCREMENT,
    feed_id           BIGINT        NOT NULL,
    image_url         VARCHAR(500)  NOT NULL,
    image_type        VARCHAR(10)   NOT NULL COMMENT 'BEFORE, AFTER',
    sort_order        INT           NOT NULL DEFAULT 0,
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (feed_image_id),
    INDEX idx_feed_id (feed_id),
    CONSTRAINT fk_feed_image_feed
        FOREIGN KEY (feed_id) REFERENCES tb_feed (feed_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tb_feed_like (
    feed_like_id      BIGINT        NOT NULL AUTO_INCREMENT,
    feed_id           BIGINT        NOT NULL,
    member_id         BIGINT        NOT NULL,
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (feed_like_id),
    UNIQUE KEY uk_feed_member (feed_id, member_id),
    INDEX idx_member_id (member_id),
    CONSTRAINT fk_feed_like_feed
        FOREIGN KEY (feed_id) REFERENCES tb_feed (feed_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_feed_like_member
        FOREIGN KEY (member_id) REFERENCES tb_member (member_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tb_feed_equipment (
    feed_equipment_id BIGINT        NOT NULL AUTO_INCREMENT,
    feed_id           BIGINT        NOT NULL,
    equipment_id      BIGINT        NOT NULL COMMENT 'tb_equipment.equipment_id (P1-007에서 생성)',
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (feed_equipment_id),
    INDEX idx_feed_id (feed_id),
    CONSTRAINT fk_feed_equipment_feed
        FOREIGN KEY (feed_id) REFERENCES tb_feed (feed_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
