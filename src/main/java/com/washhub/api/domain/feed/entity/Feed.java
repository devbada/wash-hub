package com.washhub.api.domain.feed.entity;

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
@Table(name = "tb_feed")
@Entity
public class Feed extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "feed_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @Column(name = "content", columnDefinition = "TEXT")
    private String content;

    @Column(name = "thumbnail_url", length = 500)
    private String thumbnailUrl;

    @Column(name = "wash_location", length = 100)
    private String washLocation;

    @Column(name = "like_count", nullable = false)
    private int likeCount;

    @Column(name = "comment_count", nullable = false)
    private int commentCount;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private FeedStatus status;

    @OneToMany(mappedBy = "feed", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<FeedImage> images = new ArrayList<>();

    @OneToMany(mappedBy = "feed", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<FeedEquipment> equipments = new ArrayList<>();

    @Builder
    private Feed(Member member, String content, String washLocation) {
        this.member = member;
        this.content = content;
        this.washLocation = washLocation;
        this.likeCount = 0;
        this.commentCount = 0;
        this.status = FeedStatus.ACTIVE;
    }

    public void updateContent(String content, String washLocation) {
        this.content = content;
        this.washLocation = washLocation;
    }

    public void updateThumbnailUrl(String thumbnailUrl) {
        this.thumbnailUrl = thumbnailUrl;
    }

    public void softDelete() {
        this.status = FeedStatus.DELETED;
    }

    public boolean isActive() {
        return this.status == FeedStatus.ACTIVE;
    }

    public boolean isOwnedBy(Long memberId) {
        return this.member.getId().equals(memberId);
    }

    public void increaseLikeCount() {
        this.likeCount++;
    }

    public void decreaseLikeCount() {
        if (this.likeCount > 0) {
            this.likeCount--;
        }
    }

    public void increaseCommentCount() {
        this.commentCount++;
    }

    public void decreaseCommentCount() {
        if (this.commentCount > 0) {
            this.commentCount--;
        }
    }

    public void addImage(FeedImage image) {
        this.images.add(image);
    }

    public void addEquipment(FeedEquipment equipment) {
        this.equipments.add(equipment);
    }
}
