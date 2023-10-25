"! <ol>
"!    <li>Reads flights from HANA DB</li>
"!    <li>Converts currency to EUR</li>
"! </ol>
"! <p>Implements the interface { @link INTF: if_oo_adt_classrun } </p>
"! <p class="shorttext synchronized">Class tests AMDP: </p>
CLASS zcl_amdp_demo_583 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_amdp_marker_hdb.
    INTERFACES if_oo_adt_classrun.

    "! <p class="shorttext synchronized">Table type of Flights from HANA DB</p>
    TYPES:
      BEGIN OF ty_result_line,
        airline           TYPE /dmo/carrier_name,
        flight_connection TYPE /dmo/connection_id,
        old_price         TYPE /dmo/flight_price,
        old_currency      TYPE /dmo/currency_code,
        new_price         TYPE /dmo/flight_price,
        new_currency      TYPE /dmo/currency_code,
      END OF ty_result_line,

      BEGIN OF ty_flights_line,
        airline           TYPE /dmo/carrier_name,
        flight_connection TYPE /dmo/connection_id,
        price             TYPE /dmo/flight_price,
        currency          TYPE /dmo/currency_code,
      END OF ty_flights_line,

      ty_result_table  TYPE STANDARD TABLE OF ty_result_line WITH EMPTY KEY,
      ty_flights_table TYPE STANDARD TABLE OF ty_flights_line WITH EMPTY KEY,
      ty_flights       TYPE STANDARD TABLE OF /dmo/flight.

    METHODS get_flights
      EXPORTING VALUE(result) TYPE ty_result_table
      RAISING   cx_amdp_execution_error.

    "! <p class="shorttext synchronized"> Method reads flights from HANA DB using AMDP</p>
    METHODS convert_currency
      IMPORTING VALUE(flights) TYPE ty_flights_table
      EXPORTING VALUE(result)  TYPE ty_result_table
      RAISING   cx_amdp_execution_error.
ENDCLASS.


CLASS zcl_amdp_demo_583 IMPLEMENTATION.
  METHOD convert_currency BY DATABASE PROCEDURE
    FOR HDB
    LANGUAGE SQLSCRIPT
    OPTIONS READ-ONLY.
    declare today date;
    declare new_currency nvarchar(3);

    select current_date into today from dummy;
    new_currency := 'EUR';

    result = select distinct
      airline,
      flight_connection,
      price    as old_price,
      currency as old_currency,
      convert_currency(
        "AMOUNT"          => price,
        "SOURCE_UNIT"     => currency,
        "TARGET_UNIT"     => :new_currency,
        "REFERENCE_DATE"  => :today,
        "CLIENT"          => '100',
        "ERROR_HANDLING"  => 'set to null',
        "SCHEMA"          => current_schema
      ) as new_price,
      :new_currency as new_currency
      from :flights;
  ENDMETHOD.

  METHOD get_flights BY DATABASE PROCEDURE
    FOR HDB
    LANGUAGE SQLSCRIPT
    OPTIONS READ-ONLY
    USING
      /dmo/flight
      /dmo/carrier
      zcl_amdp_demo_583=>convert_currency.
    flights = select distinct
        c.name as airline,
        f.connection_id as flight_connection,
        f.price    as price,
        f.currency_code as currency
        from "/DMO/FLIGHT"  as f
        inner join "/DMO/CARRIER" as c on f.carrier_id = c.carrier_id;

  call "ZCL_AMDP_DEMO_583=>CONVERT_CURRENCY"( :flights, result );
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
    TRY.
        get_flights( IMPORTING result = FINAL(lt_result) ).
      CATCH cx_amdp_execution_error INTO FINAL(lx_amdp).
        out->write( lx_amdp->get_longtext( ) ).
    ENDTRY.

    out->write( lt_result ).
  ENDMETHOD.
ENDCLASS.
