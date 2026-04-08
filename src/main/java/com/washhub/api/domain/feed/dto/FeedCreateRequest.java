package com.washhub.api.domain.feed.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.validation.constraints.NotEmpty;
import java.util.List;

@Getter
@NoArgsConstructor
public class FeedCreateRequest {

    private String content;

    @NotEmpty(message = "Before 이미지 URL은 최소 1개 필수입니다.")
    private List<String> beforeImageUrls;

    @NotEmpty(message = "After 이미지 URL은 최소 1개 필수입니다.")
    private List<String> afterImageUrls;

    private String washLocation;

    private List<Long> equipmentIds;
}
