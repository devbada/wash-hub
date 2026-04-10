package com.washhub.api.domain.file.service;

import com.washhub.api.domain.file.dto.FileUploadResponse;
import com.washhub.api.infra.s3.S3Service;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@RequiredArgsConstructor
@Service
public class FileUploadService {

    private final S3Service s3Service;
    private final FileValidator fileValidator;

    /**
     * 단일 이미지 업로드
     */
    public FileUploadResponse uploadSingle(MultipartFile file, String directory) {
        fileValidator.validateImage(file);
        String url = s3Service.upload(file, directory);
        log.info("단일 파일 업로드 완료: directory={}", directory);
        return FileUploadResponse.of(url);
    }

    /**
     * 다중 이미지 업로드
     */
    public FileUploadResponse uploadMultiple(List<MultipartFile> files, String directory) {
        files.forEach(fileValidator::validateImage);
        List<String> urls = files.stream()
                .map(file -> s3Service.upload(file, directory))
                .collect(Collectors.toList());
        log.info("다중 파일 업로드 완료: directory={}, count={}", directory, urls.size());
        return FileUploadResponse.of(urls);
    }
}
