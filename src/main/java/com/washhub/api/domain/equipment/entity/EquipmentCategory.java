package com.washhub.api.domain.equipment.entity;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum EquipmentCategory {

    CLEANSER("세정제"),
    PROTECTOR("보호제"),
    TOOL("도구"),
    ETC("기타");

    private final String description;
}
