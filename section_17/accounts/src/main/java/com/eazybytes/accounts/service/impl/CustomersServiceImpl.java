package com.eazybytes.accounts.service.impl;

import com.eazybytes.accounts.dto.AccountsDto;
import com.eazybytes.accounts.dto.CardsDto;
import com.eazybytes.accounts.dto.CustomerDetailsDto;
import com.eazybytes.accounts.dto.LoansDto;
import com.eazybytes.accounts.entity.Accounts;
import com.eazybytes.accounts.entity.Customer;
import com.eazybytes.accounts.exception.ResourceNotFoundException;
import com.eazybytes.accounts.mapper.AccountsMapper;
import com.eazybytes.accounts.mapper.CustomerMapper;
import com.eazybytes.accounts.repository.AccountsRepository;
import com.eazybytes.accounts.repository.CustomerRepository;
import com.eazybytes.accounts.service.ICustomersService;
import com.eazybytes.accounts.service.client.CardsClient;
import com.eazybytes.accounts.service.client.LoansClient;
import lombok.AllArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

@Service
@AllArgsConstructor
public class CustomersServiceImpl implements ICustomersService {

    private static final Logger logger = LoggerFactory.getLogger(CustomersServiceImpl.class);
    private AccountsRepository accountsRepository;
    private CustomerRepository customerRepository;
    private CardsClient cardsClient;
    private LoansClient loansClient;


    @Override
    public CustomerDetailsDto fetchCustomerDetails(String mobileNumber) {
        logger.debug("Looking up customer by mobileNumber: {}", mobileNumber);
        Customer customer = customerRepository.findByMobileNumber(mobileNumber).orElseThrow(
                () -> new ResourceNotFoundException("Customer", "mobileNumber", mobileNumber)
        );
        Accounts accounts = accountsRepository.findByCustomerId(customer.getCustomerId()).orElseThrow(
                () -> new ResourceNotFoundException("Account", "customerId", customer.getCustomerId().toString())
        );

        CustomerDetailsDto customerDetailsDto = CustomerMapper.mapToCustomerDetailsDto(customer, new CustomerDetailsDto());
        customerDetailsDto.setAccountsDto(AccountsMapper.mapToAccountsDto(accounts, new AccountsDto()));

        logger.debug("Calling loans service for mobileNumber: {}", mobileNumber);
        ResponseEntity<LoansDto> loansDtoResponseEntity = loansClient.fetchLoanDetails(mobileNumber);
        if(null != loansDtoResponseEntity) {
            customerDetailsDto.setLoansDto(loansDtoResponseEntity.getBody());
        } else {
            logger.warn("Loans service call failed or fell back for mobileNumber: {}", mobileNumber);
        }

        logger.debug("Calling cards service for mobileNumber: {}", mobileNumber);
        ResponseEntity<CardsDto> cardsDtoResponseEntity = cardsClient.fetchCardDetails(mobileNumber);
        if(null != cardsDtoResponseEntity) {
            customerDetailsDto.setCardsDto(cardsDtoResponseEntity.getBody());
        } else {
            logger.warn("Cards service call failed or fell back for mobileNumber: {}", mobileNumber);
        }
        return customerDetailsDto;

    }
}
