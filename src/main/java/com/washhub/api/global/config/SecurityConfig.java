package com.washhub.api.global.config;

import com.washhub.api.global.security.JwtAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfigurationSource;

@RequiredArgsConstructor
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final CorsConfigurationSource corsConfigurationSource;
    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .cors().configurationSource(corsConfigurationSource)
                .and()
                .csrf().disable()
                .sessionManagement().sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                .and()
                .formLogin().disable()
                .httpBasic().disable()
                .authorizeRequests()
                    // 공개 API
                    .antMatchers("/actuator/**").permitAll()
                    .antMatchers("/api/v1/auth/kakao").permitAll()
                    .antMatchers("/api/v1/auth/refresh").permitAll()
                    .antMatchers(HttpMethod.GET, "/api/v1/members/check-nickname").permitAll()
                    .antMatchers(HttpMethod.GET, "/api/v1/feeds").permitAll()
                    .antMatchers(HttpMethod.GET, "/api/v1/feeds/{feedId}").permitAll()
                    .antMatchers(HttpMethod.GET, "/api/v1/feeds/{feedId}/comments").permitAll()
                    .antMatchers(HttpMethod.GET, "/api/v1/equipments").permitAll()
                    .antMatchers(HttpMethod.GET, "/api/v1/equipments/search").permitAll()
                    .antMatchers(HttpMethod.GET, "/api/v1/equipments/{equipmentId}").permitAll()
                    // 나머지는 인증 필요
                    .anyRequest().authenticated()
                .and()
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
