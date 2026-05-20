package io.makewebsite.exception;

public class StoreFrozenException extends RuntimeException {
    public StoreFrozenException(String message) {
        super(message);
    }
}
