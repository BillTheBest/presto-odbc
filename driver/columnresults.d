
import std.array : front, empty, popFront;
import std.conv : text, to;
import std.variant : Variant;

import sqlext;
import odbcinst;

import bindings : OdbcResult, OdbcResultRow;
import util : dllEnforce, logMessage, makeWithoutGC, runQuery;
import dapi.util : asBool;

auto listColumnsInTable(string tableName) {
  auto client = runQuery("SHOW COLUMNS FROM " ~ text(tableName));
  auto result = makeWithoutGC!ColumnsResult();
  foreach (resultBatch; client) {
    foreach (i, row; resultBatch.data.array) {
      auto columnName = row.array[0].str;
      auto type = row.array[1].str;
      auto isNullable = asBool(row.array[2]) ? Nullability.SQL_NULLABLE : Nullability.SQL_NO_NULLS;
      auto partitionKey = asBool(row.array[3]);

      auto columnsResult = prestoTypeToColumnsResult(type, text(tableName), columnName, isNullable, i + 1);
      if (columnsResult) {
        result.addColumn(columnsResult);
      }
      logMessage("listColumnsInTable found column: ", columnName, type, isNullable, i + 1);
    }
  }
  return result;
}

OdbcResultRow prestoTypeToColumnsResult(
    string prestoType, string tableName, string columnName,
    Nullability isNullable, size_t ordinalPosition) {
  dllEnforce(ordinalPosition != 0, "Columns are 1-indexed");
  switch (prestoType) {
  case "varchar":
    return makeWithoutGC!VarcharColumnsResultRow(tableName, columnName, isNullable, ordinalPosition);
  case "bigint":
    return makeWithoutGC!IntegerColumnsResultRow(tableName, columnName, isNullable, ordinalPosition);
  case "double":
    return makeWithoutGC!DoubleColumnsResultRow(tableName, columnName, isNullable, ordinalPosition);
  default:
    logMessage("Unexpected type in listColumnsInTable: " ~ prestoType);
    return null;
  }
}

final class ColumnsResult : OdbcResult {
  void addColumn(OdbcResultRow column) {
    results_ ~= column;
  }

  @property {
    auto results() const {
      return results_;
    }

    bool empty() {
      return results_.empty;
    }

    OdbcResultRow front() {
      assert(!empty);
      return results_.front;
    }

    void popFront() {
      results_.popFront();
    }

    uint numberOfColumns() {
      return ColumnsResultColumns.max;
    }
  }

private:
  OdbcResultRow[] results_;
}

//bufferLengths taken from the Column Size MSDN page
alias BigIntColumnsResultRow = BigIntBasedColumnsResultRow!(SQL_TYPE_ID.SQL_BIGINT, 19);
alias IntegerColumnsResultRow = BigIntBasedColumnsResultRow!(SQL_TYPE_ID.SQL_INTEGER, 10);
alias SmallIntColumnsResultRow = BigIntBasedColumnsResultRow!(SQL_TYPE_ID.SQL_SMALLINT, 5);
alias TinyIntColumnsResultRow = BigIntBasedColumnsResultRow!(SQL_TYPE_ID.SQL_TINYINT, 3);

final class BigIntBasedColumnsResultRow(SQL_TYPE_ID typeId, int bufferLength) : OdbcResultRow {
  this(string tableName, string columnName, Nullability isNullable, size_t ordinalPosition) {
    this.tableName = tableName;
    this.columnName = columnName;
    this.isNullable = isNullable;
    this.ordinalPosition = to!int(ordinalPosition);
  }

  Variant dataAt(ColumnsResultColumns column) {
    return dataAt(cast(int) column);
  }

  Variant dataAt(int column) {
    with (ColumnsResultColumns) {
      switch (column) {
      case TABLE_CAT:
        return Variant("tpch");
      case TABLE_SCHEM:
        return Variant("tiny");
      case TABLE_NAME:
        return Variant(tableName);
      case COLUMN_NAME:
        return Variant(columnName);
      case DATA_TYPE:
      case SQL_DATA_TYPE:
        return Variant(typeId);
      case TYPE_NAME:
        return Variant("BIGINT");
      case COLUMN_SIZE:
      case BUFFER_LENGTH:
        return Variant(bufferLength);
      case DECIMAL_DIGITS:
        return Variant(0);
      case NUM_PREC_RADIX:
        return Variant(10);
      case NULLABLE:
        return Variant(isNullable);
      case REMARKS:
        return Variant("No remarks");
      case COLUMN_DEF:
        return Variant("0");
      case SQL_DATETIME_SUB:
        return Variant(null);
      case CHAR_OCTET_LENGTH:
        return Variant(null);
      case ORDINAL_POSITION:
        return Variant(ordinalPosition);
      case IS_NULLABLE:
        return Variant(isNullable);
      default:
        dllEnforce(false, "Non-existant column " ~ text(cast(ColumnsResultColumns) column));
        assert(false, "Silence compiler errors about not returning");
      }
    }
  }
private:
  string tableName;
  string columnName;
  Nullability isNullable;
  int ordinalPosition;
}

alias DoubleColumnsResultRow = DoubleBasedColumnsResultRow!(SQL_TYPE_ID.SQL_DOUBLE, 15);
alias FloatColumnsResultRow = DoubleBasedColumnsResultRow!(SQL_TYPE_ID.SQL_FLOAT, 15);
alias RealColumnsResultRow = DoubleBasedColumnsResultRow!(SQL_TYPE_ID.SQL_REAL, 7);

final class DoubleBasedColumnsResultRow(SQL_TYPE_ID typeId, int bufferLength) : OdbcResultRow {
  this(string tableName, string columnName, Nullability isNullable, size_t ordinalPosition) {
    this.tableName = tableName;
    this.columnName = columnName;
    this.isNullable = isNullable;
    this.ordinalPosition = to!int(ordinalPosition);
  }

  Variant dataAt(ColumnsResultColumns column) {
    return dataAt(cast(int) column);
  }

  Variant dataAt(int column) {
    with (ColumnsResultColumns) {
      switch (column) {
      case TABLE_CAT:
        return Variant("tpch");
      case TABLE_SCHEM:
        return Variant("tiny");
      case TABLE_NAME:
        return Variant(tableName);
      case COLUMN_NAME:
        return Variant(columnName);
      case DATA_TYPE:
      case SQL_DATA_TYPE:
        return Variant(typeId);
      case TYPE_NAME:
        return Variant("DOUBLE");
      case COLUMN_SIZE:
      case BUFFER_LENGTH:
        return Variant(bufferLength);
      case DECIMAL_DIGITS:
        return Variant(null);
      case NUM_PREC_RADIX:
        return Variant(10);
      case NULLABLE:
        return Variant(isNullable);
      case REMARKS:
        return Variant("No remarks");
      case COLUMN_DEF:
        return Variant("0");
      case SQL_DATETIME_SUB:
        return Variant(null);
      case CHAR_OCTET_LENGTH:
        return Variant(null);
      case ORDINAL_POSITION:
        return Variant(ordinalPosition);
      case IS_NULLABLE:
        return Variant(isNullable);
      default:
        dllEnforce(false, "Non-existant column " ~ text(cast(ColumnsResultColumns) column));
        assert(false, "Silence compiler errors about not returning");
      }
    }
  }
private:
  string tableName;
  string columnName;
  Nullability isNullable;
  int ordinalPosition;
}


final class VarcharColumnsResultRow : OdbcResultRow {
  this(string tableName, string columnName, Nullability isNullable, size_t ordinalPosition) {
    this.tableName = tableName;
    this.columnName = columnName;
    this.isNullable = isNullable;
    this.ordinalPosition = cast(int) ordinalPosition;
  }
  Variant dataAt(int column) {
    with (ColumnsResultColumns) {
      switch (column) {
      case TABLE_CAT:
        return Variant("tpch");
      case TABLE_SCHEM:
        return Variant("tiny");
      case TABLE_NAME:
        return Variant(tableName);
      case COLUMN_NAME:
        return Variant(columnName);
      case DATA_TYPE:
      case SQL_DATA_TYPE:
        return Variant(SQL_TYPE_ID.SQL_VARCHAR);
      case TYPE_NAME:
        return Variant("VARCHAR");
      case COLUMN_SIZE:
      case BUFFER_LENGTH:
        return Variant(SQL_NO_TOTAL);
      case DECIMAL_DIGITS:
        return Variant(null);
      case NUM_PREC_RADIX:
        return Variant(null);
      case NULLABLE:
        return Variant(isNullable);
      case REMARKS:
        return Variant("No remarks");
      case COLUMN_DEF:
        return Variant("''");
      case SQL_DATETIME_SUB:
        return Variant(null);
      case CHAR_OCTET_LENGTH:
        return Variant(SQL_NO_TOTAL); //not sure if this value works here
      case ORDINAL_POSITION:
        return Variant(ordinalPosition);
      case IS_NULLABLE:
        return Variant(isNullable);
      default:
        dllEnforce(false, "Non-existant column " ~ text(cast(ColumnsResultColumns) column));
        assert(false, "Silence compiler errors about not returning");
      }
    }
  }
private:
  string tableName;
  string columnName;
  Nullability isNullable;
  int ordinalPosition;
}

enum ColumnsResultColumns {
  TABLE_CAT = 1,
  TABLE_SCHEM,
  TABLE_NAME,
  COLUMN_NAME,
  DATA_TYPE,
  TYPE_NAME,
  COLUMN_SIZE,
  BUFFER_LENGTH, //How many bytes a BindCol buffer must have to accept this
  DECIMAL_DIGITS,
  NUM_PREC_RADIX,
  NULLABLE,
  REMARKS,
  COLUMN_DEF,
  SQL_DATA_TYPE,
  SQL_DATETIME_SUB,
  CHAR_OCTET_LENGTH,
  ORDINAL_POSITION, //Which # column in the table this is
  IS_NULLABLE
}
