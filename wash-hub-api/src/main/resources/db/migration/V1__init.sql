-- V1: 회원 및 소셜 계정 테이블 생성
-- Feature: P1-002-auth

CREATE TABLE tb_member (
    member_id         BIGINT       NOT NULL AUTO_INCREMENT,
    nickname          VARCHAR(30)  NULL UNIQUE,
    profile_image_url VARCHAR(500) NULL,
    role              VARCHAR(20)  NOT NULL DEFAULT 'USER',
    status            VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (member_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tb_social_account (
    social_account_id BIGINT       NOT NULL AUTO_INCREMENT,
    member_id         BIGINT       NOT NULL,
    provider          VARCHAR(20)  NOT NULL COMMENT 'KAKAO, APPLE, NAVER',
    provider_id       VARCHAR(100) NOT NULL,
    connected_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (social_account_id),
    UNIQUE KEY uk_provider_provider_id (provider, provider_id),
    INDEX idx_member_id (member_id),
    CONSTRAINT fk_social_account_member
        FOREIGN KEY (member_id) REFERENCES tb_member (member_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
