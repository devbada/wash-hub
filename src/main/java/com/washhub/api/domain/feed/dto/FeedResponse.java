package com.washhub.api.domain.feed.dto;

import com.washhub.api.domain.feed.entity.Feed;
import com.washhub.api.domain.feed.entity.ImageType;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Getter
@Builder
public class FeedResponse {

    private final Long feedId;
    private final WriterInfo writer;
    private final String content;
    private final String thumbnailUrl;
    private final String washLocation;
    private final int likeCount;
    private final int commentCount;
    private final boolean liked;
    private final List<FeedImageDto> beforeImages;
    private final List<FeedImageDto> afterImages;
    private final List<Long> equipmentIds;
    private final LocalDateTime createdAt;

    @Getter
    @Builder
    public static class WriterInfo {
        private final Long memberId;
        private final String nickname;
        private final String profileImageUrl;
    }

    public static FeedResponse from(Feed feed, boolean liked) {
        List<FeedImageDto> beforeImages = feed.getImages().stream()
                .filter(img -> img.getImageType() == ImageType.BEFORE)
                .map(FeedImageDto::from)
                .collect(Collectors.toList());

        List<FeedImageDto> afterImages = feed.getImages().stream()
                .filter(img -> img.getImageType() == ImageType.AFTER)
                .map(FeedImageDto::from)
                .collect(Collectors.toList());

        List<Long> equipmentIds = feed.getEquipments().stream()
                .map(eq -> eq.getEquipmentId())
                .collect(Collectors.toList());

        WriterInfo writerInfo = WriterInfo.builder()
                .memberId(feed.getMember().getId())
                .nickname(feed.getMember().getNickname())
                .profileImageUrl(feed.getMember().getProfileImageUrl())
                .build();

        return FeedResponse.builder()
                .feedId(feed.getId())
                .writer(writerInfo)
                .content(feed.getContent())
                .thumbnailUrl(feed.getThumbnailUrl())
                .washLocation(feed.getWashLocation())
                .likeCount(feed.getLikeCount())
                .commentCount(feed.getCommentCount())
                .liked(liked)
                .beforeImages(beforeImages)
                .afterImages(afterImages)
                .equipmentIds(equipmentIds)
                .createdAt(feed.getCreatedAt())
                .build();
    }
}
