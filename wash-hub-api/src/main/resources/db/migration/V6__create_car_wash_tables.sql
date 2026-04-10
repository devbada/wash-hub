-- P1-008: 세차장 기본 테이블
CREATE TABLE tb_car_wash (
    car_wash_id     BIGINT          NOT NULL AUTO_INCREMENT,
    member_id       BIGINT          NOT NULL,
    name            VARCHAR(100)    NOT NULL COMMENT '세차장명',
    category        VARCHAR(30)     NOT NULL COMMENT '유형 (SELF, AUTO, HAND, DETAIL)',
    address         VARCHAR(300)    NULL COMMENT '주소',
    latitude        DECIMAL(10,7)   NULL COMMENT '위도',
    longitude       DECIMAL(10,7)   NULL COMMENT '경도',
    phone           VARCHAR(20)     NULL COMMENT '전화번호',
    operating_hours VARCHAR(100)    NULL COMMENT '영업시간',
    price_range     VARCHAR(50)     NULL COMMENT '가격대',
    image_url       VARCHAR(500)    NULL COMMENT '대표 이미지',
    avg_rating      DECIMAL(2,1)    NOT NULL DEFAULT 0.0 COMMENT '평균 별점',
    review_count    INT             NOT NULL DEFAULT 0 COMMENT '리뷰 수',
    status          VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE' COMMENT '상태 (ACTIVE, DELETED)',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (car_wash_id),
    INDEX idx_car_wash_category (category),
    INDEX idx_car_wash_member (member_id),
    INDEX idx_car_wash_status (status),
    INDEX idx_car_wash_location (latitude, longitude),
    CONSTRAINT fk_car_wash_member FOREIGN KEY (member_id) REFERENCES tb_member (member_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tb_car_wash_facility (
    facility_id     BIGINT          NOT NULL AUTO_INCREMENT,
    car_wash_id     BIGINT          NOT NULL,
    facility_type   VARCHAR(30)     NOT NULL COMMENT '시설 유형 (HIGH_PRESSURE, AIR_GUN, MAT_WASHER, VACUUM, PARKING, OPEN_24H)',
    PRIMARY KEY (facility_id),
    INDEX idx_facility_car_wash (car_wash_id),
    CONSTRAINT fk_facility_car_wash FOREIGN KEY (car_wash_id) REFERENCES tb_car_wash (car_wash_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
