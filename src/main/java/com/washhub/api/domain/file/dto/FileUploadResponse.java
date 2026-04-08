package com.washhub.api.domain.file.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

import java.util.List;

@Getter
@AllArgsConstructor
public class FileUploadResponse {

    private final List<String> urls;

    public static FileUploadResponse of(List<String> urls) {
        return new FileUploadResponse(urls);
    }

    public static FileUploadResponse of(String url) {
        return new FileUploadResponse(List.of(url));
    }
}
