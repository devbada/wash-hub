-- P1-007: 케미컬/장비 기본 테이블
CREATE TABLE tb_equipment (
    equipment_id    BIGINT          NOT NULL AUTO_INCREMENT,
    member_id       BIGINT          NOT NULL,
    category        VARCHAR(30)     NOT NULL COMMENT '카테고리 (CLEANSER, PROTECTOR, TOOL, ETC)',
    name            VARCHAR(100)    NOT NULL COMMENT '제품명',
    brand           VARCHAR(100)    NULL COMMENT '브랜드',
    description     TEXT            NULL COMMENT '설명',
    image_url       VARCHAR(500)    NULL COMMENT '대표 이미지',
    avg_rating      DECIMAL(2,1)    NOT NULL DEFAULT 0.0 COMMENT '평균 별점',
    review_count    INT             NOT NULL DEFAULT 0 COMMENT '리뷰 수',
    status          VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE' COMMENT '상태 (ACTIVE, DELETED)',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (equipment_id),
    INDEX idx_equipment_category (category),
    INDEX idx_equipment_member (member_id),
    INDEX idx_equipment_status (status),
    CONSTRAINT fk_equipment_member FOREIGN KEY (member_id) REFERENCES tb_member (member_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
