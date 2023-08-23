package com.eazybytes.accounts.dto;

/**
 * @param accountNumber
 * @param name
 * @param email
 * @param mobileNumber
 */
public record AccountsMsgDto(
        Long accountNumber, String name, String email, String mobileNumber
){}
