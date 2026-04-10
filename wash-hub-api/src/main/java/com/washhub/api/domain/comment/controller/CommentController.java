package com.washhub.api.domain.comment.controller;

import com.washhub.api.domain.comment.dto.CommentCreateRequest;
import com.washhub.api.domain.comment.dto.CommentResponse;
import com.washhub.api.domain.comment.dto.CommentUpdateRequest;
import com.washhub.api.domain.comment.service.CommentService;
import com.washhub.api.global.common.dto.ApiResponse;
import com.washhub.api.global.security.SecurityUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.List;

@RequiredArgsConstructor
@RestController
public class CommentController {

    private final CommentService commentService;

    /**
     * 댓글 목록 조회
     * GET /api/v1/feeds/{feedId}/comments
     */
    @GetMapping("/api/v1/feeds/{feedId}/comments")
    public ResponseEntity<ApiResponse<List<CommentResponse>>> getComments(
            @PathVariable Long feedId) {
        List<CommentResponse> response = commentService.getComments(feedId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 댓글 작성
     * POST /api/v1/feeds/{feedId}/comments
     */
    @PostMapping("/api/v1/feeds/{feedId}/comments")
    public ResponseEntity<ApiResponse<CommentResponse>> createComment(
            @PathVariable Long feedId,
            @Valid @RequestBody CommentCreateRequest request) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        CommentResponse response = commentService.createComment(feedId, memberId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(response));
    }

    /**
     * 댓글 수정
     * PUT /api/v1/comments/{commentId}
     */
    @PutMapping("/api/v1/comments/{commentId}")
    public ResponseEntity<ApiResponse<CommentResponse>> updateComment(
            @PathVariable Long commentId,
            @Valid @RequestBody CommentUpdateRequest request) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        CommentResponse response = commentService.updateComment(commentId, memberId, request);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 댓글 삭제 (soft delete)
     * DELETE /api/v1/comments/{commentId}
     */
    @DeleteMapping("/api/v1/comments/{commentId}")
    public ResponseEntity<ApiResponse<Void>> deleteComment(@PathVariable Long commentId) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        commentService.deleteComment(commentId, memberId);
        return ResponseEntity.ok(ApiResponse.success("댓글이 삭제되었습니다.", null));
    }
}
