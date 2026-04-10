package com.washhub.api.domain.feed.dto;

import com.washhub.api.domain.feed.entity.Feed;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class FeedListResponse {

    private final Long feedId;
    private final FeedResponse.WriterInfo writer;
    private final String content;
    private final String thumbnailUrl;
    private final int likeCount;
    private final int commentCount;
    private final boolean liked;
    private final LocalDateTime createdAt;

    public static FeedListResponse from(Feed feed, boolean liked) {
        FeedResponse.WriterInfo writerInfo = FeedResponse.WriterInfo.builder()
                .memberId(feed.getMember().getId())
                .nickname(feed.getMember().getNickname())
                .profileImageUrl(feed.getMember().getProfileImageUrl())
                .build();

        return FeedListResponse.builder()
                .feedId(feed.getId())
                .writer(writerInfo)
                .content(truncateContent(feed.getContent()))
                .thumbnailUrl(feed.getThumbnailUrl())
                .likeCount(feed.getLikeCount())
                .commentCount(feed.getCommentCount())
                .liked(liked)
                .createdAt(feed.getCreatedAt())
                .build();
    }

    /**
     * 목록에서 본문 미리보기 (100자 제한)
     */
    private static String truncateContent(String content) {
        if (content == null) return null;
        return content.length() > 100 ? content.substring(0, 100) + "..." : content;
    }
}
