// Copyright (c) 2019, 2021, Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

package oracle.kubernetes.operator.work;

public class InMemoryDatabaseException extends RuntimeException {
  private final int code;

  InMemoryDatabaseException(int code, String message) {
    super(message);
    this.code = code;
  }

  public int getCode() {
    return code;
  }
}
