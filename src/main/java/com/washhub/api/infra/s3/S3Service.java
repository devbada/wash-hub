package com.washhub.api.infra.s3;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.model.CannedAccessControlList;
import com.amazonaws.services.s3.model.DeleteObjectRequest;
import com.amazonaws.services.s3.model.ObjectMetadata;
import com.amazonaws.services.s3.model.PutObjectRequest;
import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@RequiredArgsConstructor
@Service
public class S3Service {

    private final AmazonS3 amazonS3;

    @Value("${cloud.aws.s3.bucket}")
    private String bucket;

    @Value("${spring.profiles.active:local}")
    private String activeProfile;

    /**
     * 단일 파일 업로드
     *
     * @param file      업로드할 파일
     * @param directory 저장 디렉토리 (예: "feeds/1")
     * @return 업로드된 파일의 S3 URL
     */
    public String upload(MultipartFile file, String directory) {
        String fileName = generateFileName(file.getOriginalFilename());
        String key = buildKey(directory, fileName);

        ObjectMetadata metadata = new ObjectMetadata();
        metadata.setContentType(file.getContentType());
        metadata.setContentLength(file.getSize());

        try (InputStream inputStream = file.getInputStream()) {
            amazonS3.putObject(new PutObjectRequest(bucket, key, inputStream, metadata)
                    .withCannedAcl(CannedAccessControlList.PublicRead));
            log.info("S3 파일 업로드 완료: key={}", key);
            return amazonS3.getUrl(bucket, key).toString();
        } catch (IOException e) {
            log.error("S3 파일 업로드 실패: {}", e.getMessage());
            throw new NotAcceptableException(ErrorCode.FILE_UPLOAD_FAILED, "파일 업로드에 실패했습니다."); // TODO-minam
        }
    }

    /**
     * 다중 파일 업로드
     */
    public List<String> uploadMultiple(List<MultipartFile> files, String directory) {
        return files.stream()
                .map(file -> upload(file, directory))
                .collect(Collectors.toList());
    }

    /**
     * byte 배열 업로드 (합성 이미지용)
     *
     * @param bytes       이미지 바이트 배열
     * @param directory   저장 디렉토리
     * @param fileName    파일명 (예: "thumbnail.jpg")
     * @param contentType MIME 타입
     * @return 업로드된 파일의 S3 URL
     */
    public String uploadBytes(byte[] bytes, String directory, String fileName, String contentType) {
        String key = buildKey(directory, fileName);

        ObjectMetadata metadata = new ObjectMetadata();
        metadata.setContentType(contentType);
        metadata.setContentLength(bytes.length);

        try (InputStream inputStream = new ByteArrayInputStream(bytes)) {
            amazonS3.putObject(new PutObjectRequest(bucket, key, inputStream, metadata)
                    .withCannedAcl(CannedAccessControlList.PublicRead));
            log.info("S3 바이트 업로드 완료: key={}", key);
            return amazonS3.getUrl(bucket, key).toString();
        } catch (IOException e) {
            log.error("S3 바이트 업로드 실패: {}", e.getMessage());
            throw new NotAcceptableException(ErrorCode.FILE_UPLOAD_FAILED, "파일 업로드에 실패했습니다."); // TODO-minam
        }
    }

    /**
     * 파일 삭제
     */
    public void delete(String fileUrl) {
        try {
            String key = extractKey(fileUrl);
            amazonS3.deleteObject(new DeleteObjectRequest(bucket, key));
            log.info("S3 파일 삭제 완료: key={}", key);
        } catch (Exception e) {
            log.error("S3 파일 삭제 실패: {}", e.getMessage());
        }
    }

    /**
     * 고유 파일명 생성
     */
    private String generateFileName(String originalFilename) {
        String extension = extractExtension(originalFilename);
        return UUID.randomUUID().toString() + "." + extension;
    }

    /**
     * S3 키 생성: {env}/{directory}/{fileName}
     */
    private String buildKey(String directory, String fileName) {
        return activeProfile + "/" + directory + "/" + fileName;
    }

    /**
     * 파일 URL에서 S3 키 추출
     */
    private String extractKey(String fileUrl) {
        return fileUrl.substring(fileUrl.indexOf(activeProfile));
    }

    /**
     * 확장자 추출
     */
    private String extractExtension(String filename) {
        if (filename == null || !filename.contains(".")) {
            throw new NotAcceptableException(ErrorCode.INVALID_FILE_TYPE, "파일 확장자를 확인할 수 없습니다."); // TODO-minam
        }
        return filename.substring(filename.lastIndexOf(".") + 1).toLowerCase();
    }
}
