package com.washhub.api.domain.feed.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@NoArgsConstructor
public class FeedUpdateRequest {

    private String content;
    private String washLocation;
    private List<Long> equipmentIds;
}
