package com.washhub.api.domain.comment.repository;

import com.washhub.api.domain.comment.entity.Comment;
import com.washhub.api.domain.comment.entity.CommentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface CommentRepository extends JpaRepository<Comment, Long> {

    /**
     * 특정 피드의 부모 댓글 목록 (대댓글 제외, 최신순)
     */
    @Query("SELECT c FROM Comment c " +
            "JOIN FETCH c.member " +
            "WHERE c.feed.id = :feedId " +
            "AND c.parentComment IS NULL " +
            "ORDER BY c.createdAt ASC")
    List<Comment> findParentCommentsByFeedId(@Param("feedId") Long feedId);

    /**
     * 특정 부모 댓글의 대댓글 목록 (최신순)
     */
    @Query("SELECT c FROM Comment c " +
            "JOIN FETCH c.member " +
            "WHERE c.parentComment.id = :parentCommentId " +
            "ORDER BY c.createdAt ASC")
    List<Comment> findRepliesByParentCommentId(@Param("parentCommentId") Long parentCommentId);
}
