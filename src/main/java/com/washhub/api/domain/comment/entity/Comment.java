package com.washhub.api.domain.comment.entity;

import com.washhub.api.domain.feed.entity.Feed;
import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.global.common.entity.BaseEntity;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.persistence.*;
import java.util.ArrayList;
import java.util.List;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "tb_comment")
@Entity
public class Comment extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "comment_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "feed_id", nullable = false)
    private Feed feed;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_comment_id")
    private Comment parentComment;

    @OneToMany(mappedBy = "parentComment")
    private List<Comment> replies = new ArrayList<>();

    @Column(name = "content", nullable = false, columnDefinition = "TEXT")
    private String content;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private CommentStatus status;

    @Builder
    private Comment(Feed feed, Member member, Comment parentComment, String content) {
        this.feed = feed;
        this.member = member;
        this.parentComment = parentComment;
        this.content = content;
        this.status = CommentStatus.ACTIVE;
    }

    public void updateContent(String content) {
        this.content = content;
    }

    public void softDelete() {
        this.status = CommentStatus.DELETED;
    }

    public boolean isActive() {
        return this.status == CommentStatus.ACTIVE;
    }

    public boolean isOwnedBy(Long memberId) {
        return this.member.getId().equals(memberId);
    }

    public boolean isReply() {
        return this.parentComment != null;
    }
}
