package com.washhub.api.domain.comment.dto;

import com.washhub.api.domain.comment.entity.Comment;
import com.washhub.api.domain.comment.entity.CommentStatus;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.List;

@Getter
@Builder
public class CommentResponse {

    private final Long commentId;
    private final WriterInfo writer;
    private final String content;
    private final String status;
    private final Long parentCommentId;
    private final List<CommentResponse> replies;
    private final LocalDateTime createdAt;
    private final LocalDateTime updatedAt;

    @Getter
    @Builder
    public static class WriterInfo {
        private final Long memberId;
        private final String nickname;
        private final String profileImageUrl;
    }

    /**
     * 댓글 엔티티 → 응답 DTO 변환
     * - 삭제된 댓글은 content를 "삭제된 댓글입니다."로 표시
     */
    public static CommentResponse from(Comment comment, List<CommentResponse> replies) {
        boolean isDeleted = comment.getStatus() == CommentStatus.DELETED;

        WriterInfo writerInfo = WriterInfo.builder()
                .memberId(comment.getMember().getId())
                .nickname(isDeleted ? null : comment.getMember().getNickname())
                .profileImageUrl(isDeleted ? null : comment.getMember().getProfileImageUrl())
                .build();

        return CommentResponse.builder()
                .commentId(comment.getId())
                .writer(writerInfo)
                .content(isDeleted ? "삭제된 댓글입니다." : comment.getContent())
                .status(comment.getStatus().name())
                .parentCommentId(comment.getParentComment() != null ? comment.getParentComment().getId() : null)
                .replies(replies)
                .createdAt(comment.getCreatedAt())
                .updatedAt(comment.getUpdatedAt())
                .build();
    }
}
