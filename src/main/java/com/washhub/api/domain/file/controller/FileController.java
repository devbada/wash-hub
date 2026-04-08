package com.washhub.api.domain.file.controller;

import com.washhub.api.domain.file.dto.FileUploadResponse;
import com.washhub.api.domain.file.service.FileUploadService;
import com.washhub.api.global.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/files")
public class FileController {

    private final FileUploadService fileUploadService;

    /**
     * 단일 이미지 업로드
     * POST /api/v1/files/upload
     */
    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<FileUploadResponse>> uploadSingle(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "directory", defaultValue = "temp") String directory) {
        FileUploadResponse response = fileUploadService.uploadSingle(file, directory);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 다중 이미지 업로드
     * POST /api/v1/files/upload/multiple
     */
    @PostMapping(value = "/upload/multiple", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<FileUploadResponse>> uploadMultiple(
            @RequestParam("files") List<MultipartFile> files,
            @RequestParam(value = "directory", defaultValue = "temp") String directory) {
        FileUploadResponse response = fileUploadService.uploadMultiple(files, directory);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
