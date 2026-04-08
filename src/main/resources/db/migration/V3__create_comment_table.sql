-- V3: 댓글 테이블 생성
-- Feature: P1-005-comment

CREATE TABLE tb_comment (
    comment_id        BIGINT        NOT NULL AUTO_INCREMENT,
    feed_id           BIGINT        NOT NULL,
    member_id         BIGINT        NOT NULL,
    parent_comment_id BIGINT        NULL COMMENT '대댓글인 경우 부모 댓글 ID (1depth만 허용)',
    content           TEXT          NOT NULL,
    status            VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE' COMMENT 'ACTIVE, DELETED',
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (comment_id),
    INDEX idx_feed_id (feed_id),
    INDEX idx_parent_comment_id (parent_comment_id),
    CONSTRAINT fk_comment_feed
        FOREIGN KEY (feed_id) REFERENCES tb_feed (feed_id),
    CONSTRAINT fk_comment_member
        FOREIGN KEY (member_id) REFERENCES tb_member (member_id),
    CONSTRAINT fk_comment_parent
        FOREIGN KEY (parent_comment_id) REFERENCES tb_comment (comment_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
