package com.washhub.api.domain.feed.dto;

import com.washhub.api.domain.feed.entity.FeedImage;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class FeedImageDto {

    private final Long feedImageId;
    private final String imageUrl;
    private final String imageType;
    private final int sortOrder;

    public static FeedImageDto from(FeedImage feedImage) {
        return FeedImageDto.builder()
                .feedImageId(feedImage.getId())
                .imageUrl(feedImage.getImageUrl())
                .imageType(feedImage.getImageType().name())
                .sortOrder(feedImage.getSortOrder())
                .build();
    }
}
