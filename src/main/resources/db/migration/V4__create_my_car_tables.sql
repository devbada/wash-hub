-- V4: 내차 및 세차 기록 테이블 생성
-- Feature: P1-006-my-car

CREATE TABLE tb_my_car (
    my_car_id         BIGINT        NOT NULL AUTO_INCREMENT,
    member_id         BIGINT        NOT NULL,
    car_model         VARCHAR(100)  NOT NULL COMMENT '차종 (예: 아반떼 CN7)',
    car_color         VARCHAR(50)   NULL COMMENT '차량 색상',
    car_year          INT           NULL COMMENT '연식',
    image_url         VARCHAR(500)  NULL COMMENT '차량 사진',
    is_primary        TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '대표 차량 여부',
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (my_car_id),
    INDEX idx_member_id (member_id),
    CONSTRAINT fk_my_car_member
        FOREIGN KEY (member_id) REFERENCES tb_member (member_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tb_wash_log (
    wash_log_id       BIGINT        NOT NULL AUTO_INCREMENT,
    member_id         BIGINT        NOT NULL,
    my_car_id         BIGINT        NULL,
    feed_id           BIGINT        NULL COMMENT '연결된 피드 (선택)',
    car_wash_id       BIGINT        NULL COMMENT '세차장 ID (P1-008에서 생성)',
    wash_date         DATE          NOT NULL,
    memo              TEXT          NULL,
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (wash_log_id),
    INDEX idx_member_id (member_id),
    INDEX idx_my_car_id (my_car_id),
    INDEX idx_wash_date (wash_date DESC),
    CONSTRAINT fk_wash_log_member
        FOREIGN KEY (member_id) REFERENCES tb_member (member_id),
    CONSTRAINT fk_wash_log_my_car
        FOREIGN KEY (my_car_id) REFERENCES tb_my_car (my_car_id)
        ON DELETE SET NULL,
    CONSTRAINT fk_wash_log_feed
        FOREIGN KEY (feed_id) REFERENCES tb_feed (feed_id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tb_wash_log_equipment (
    wash_log_equipment_id BIGINT    NOT NULL AUTO_INCREMENT,
    wash_log_id           BIGINT    NOT NULL,
    equipment_id          BIGINT    NOT NULL COMMENT 'tb_equipment.equipment_id (P1-007에서 생성)',
    created_at            DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (wash_log_equipment_id),
    INDEX idx_wash_log_id (wash_log_id),
    CONSTRAINT fk_wash_log_equipment_wash_log
        FOREIGN KEY (wash_log_id) REFERENCES tb_wash_log (wash_log_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
