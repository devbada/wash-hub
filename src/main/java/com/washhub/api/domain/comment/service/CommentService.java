package com.washhub.api.domain.comment.service;

import com.washhub.api.domain.comment.dto.CommentCreateRequest;
import com.washhub.api.domain.comment.dto.CommentResponse;
import com.washhub.api.domain.comment.dto.CommentUpdateRequest;
import com.washhub.api.domain.comment.entity.Comment;
import com.washhub.api.domain.comment.repository.CommentRepository;
import com.washhub.api.domain.feed.entity.Feed;
import com.washhub.api.domain.feed.repository.FeedRepository;
import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.domain.member.repository.MemberRepository;
import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@RequiredArgsConstructor
@Service
public class CommentService {

    private final CommentRepository commentRepository;
    private final FeedRepository feedRepository;
    private final MemberRepository memberRepository;

    /**
     * 댓글 목록 조회 (부모 댓글 + 대댓글 포함)
     */
    @Transactional(readOnly = true)
    public List<CommentResponse> getComments(Long feedId) {
        List<Comment> persistParentComments = commentRepository.findParentCommentsByFeedId(feedId);

        return persistParentComments.stream()
                .map(parentComment -> {
                    List<Comment> persistReplies = commentRepository
                            .findRepliesByParentCommentId(parentComment.getId());

                    List<CommentResponse> replyResponses = persistReplies.stream()
                            .map(reply -> CommentResponse.from(reply, Collections.emptyList()))
                            .collect(Collectors.toList());

                    return CommentResponse.from(parentComment, replyResponses);
                })
                .collect(Collectors.toList());
    }

    /**
     * 댓글 작성
     */
    @Transactional
    public CommentResponse createComment(Long feedId, Long memberId, CommentCreateRequest request) {
        Feed persistFeed = feedRepository.findById(feedId)
                .filter(Feed::isActive)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "피드를 찾을 수 없습니다.")); // TODO-minam

        Member persistMember = memberRepository.findById(memberId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")); // TODO-minam

        Comment parentComment = null;

        // 대댓글인 경우 부모 댓글 확인
        if (request.getParentCommentId() != null) {
            Comment persistParentComment = commentRepository.findById(request.getParentCommentId())
                    .filter(Comment::isActive)
                    .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "부모 댓글을 찾을 수 없습니다.")); // TODO-minam

            // 1depth만 허용: 대댓글에 대댓글 금지
            if (persistParentComment.isReply()) {
                throw new NotAcceptableException("대댓글에는 답글을 달 수 없습니다. (1depth만 허용)"); // TODO-minam
            }

            parentComment = persistParentComment;
        }

        Comment persistComment = Comment.builder()
                .feed(persistFeed)
                .member(persistMember)
                .parentComment(parentComment)
                .content(request.getContent())
                .build();
        persistComment = commentRepository.save(persistComment);

        // 피드 댓글 수 증가
        persistFeed.increaseCommentCount();

        log.info("댓글 작성 완료: commentId={}, feedId={}, isReply={}", persistComment.getId(), feedId, parentComment != null);
        return CommentResponse.from(persistComment, Collections.emptyList());
    }

    /**
     * 댓글 수정 (본인만)
     */
    @Transactional
    public CommentResponse updateComment(Long commentId, Long memberId, CommentUpdateRequest request) {
        Comment persistComment = commentRepository.findById(commentId)
                .filter(Comment::isActive)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "댓글을 찾을 수 없습니다.")); // TODO-minam

        if (!persistComment.isOwnedBy(memberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인의 댓글만 수정할 수 있습니다."); // TODO-minam
        }

        persistComment.updateContent(request.getContent());
        log.info("댓글 수정 완료: commentId={}", commentId);

        // 대댓글 목록 조회 (부모 댓글인 경우)
        List<CommentResponse> replies = Collections.emptyList();
        if (!persistComment.isReply()) {
            List<Comment> persistReplies = commentRepository.findRepliesByParentCommentId(commentId);
            replies = persistReplies.stream()
                    .map(reply -> CommentResponse.from(reply, Collections.emptyList()))
                    .collect(Collectors.toList());
        }

        return CommentResponse.from(persistComment, replies);
    }

    /**
     * 댓글 삭제 - soft delete (본인만)
     */
    @Transactional
    public void deleteComment(Long commentId, Long memberId) {
        Comment persistComment = commentRepository.findById(commentId)
                .filter(Comment::isActive)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "댓글을 찾을 수 없습니다.")); // TODO-minam

        if (!persistComment.isOwnedBy(memberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인의 댓글만 삭제할 수 있습니다."); // TODO-minam
        }

        persistComment.softDelete();

        // 피드 댓글 수 감소
        persistComment.getFeed().decreaseCommentCount();

        log.info("댓글 삭제 완료: commentId={}", commentId);
    }
}
