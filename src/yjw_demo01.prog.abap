* title 调用restful接口批量下载附件并压缩保存至本机
REPORT yjw_demo01.

DATA: lt_str TYPE TABLE OF string WITH HEADER LINE,
      lv_str TYPE string.

DATA: lv_data TYPE xstring.
DATA: lo_client TYPE REF TO if_http_client.
DATA: lo_zip  TYPE REF TO cl_abap_zip.

DATA: lv_filename TYPE string VALUE '',
      lv_fullpath TYPE string,
      lv_path     TYPE  string.
DATA: lv_name TYPE string.
DATA: lv_zip_size     TYPE i,
      lt_zip_bin_data TYPE STANDARD TABLE OF raw255.

START-OF-SELECTION.

  CREATE OBJECT lo_zip.

  lv_str = 'http://60.174.92.45:8081/files/ccs/03/03E1D9E1304844D5B6C4239A2E54F415.jpg;' &&
  'http://60.174.92.45:8081/files/ccs/1D/1D4935EA6C7E42088F692BBDF5DDC489.jpg;' &&
  'http://60.174.92.45:8081/files/ccs/75/7581F38FA7654923B6406436CB4D5960.jpg;' &&
  'http://60.174.92.45:8081/files/ccs/00/003A774839F5482AA0C6FC1C75389DCF.jpg;' &&
  'http://60.174.92.45:8081/files/ccs/0D/0D7C56DF199548B7914B6AA8DCD61E3E.jpg;' &&
  'http://60.174.92.45:8081/files/ccs/AC/ACD68856BAEA4137B2B139DE45F48686.jpg;' &&
  'http://60.174.92.45:8081/files/ccs/73/730C0B3503134A318608A1D58618753B.jpg;' &&
  'http://60.174.92.45:8081/files/ccs/0E/0E32B96A99E04F8E8D8977FC06E1FAC1.jpg;' &&
  'http://60.174.92.45:8081/files/ccs/A5/A585F8E34F834153BF49C3EB521FAF36.jpg;' &&
  'http://60.174.92.45:8081/files/ccs/5E/5E059B84593F4D80A3FA7F8B4CC29359.jpg'.


  SPLIT lv_str AT ';' INTO TABLE lt_str.

  LOOP AT lt_str.

    CALL METHOD cl_http_client=>create_by_url
      EXPORTING
        url                = lt_str
      IMPORTING
        client             = lo_client
      EXCEPTIONS
        argument_not_found = 1
        plugin_not_active  = 2
        internal_error     = 3
        OTHERS             = 4.
    IF sy-subrc NE 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
    lo_client->request->set_header_field( name  = '~request_method'
                                            value = 'GET' ).


    CALL METHOD lo_client->send
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4.
    IF sy-subrc NE 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

* Prepare client-receive:
    CALL METHOD lo_client->receive
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4.

* Get content
    lv_data = lo_client->response->get_data( ).

* 压缩文件
    CLEAR lv_name.
    DATA: lv_filep   TYPE  c LENGTH 1000,
          lv_pfxpath TYPE  draw-filep,
          lv_pfxfile TYPE draw-filep.

    lv_filep = lt_str.

    CALL FUNCTION 'CV120_SPLIT_PATH'
      EXPORTING
        pf_path  = lv_filep
      IMPORTING
        pfx_path = lv_pfxpath
        pfx_file = lv_pfxfile.


    lv_name =  lv_pfxfile.

    lo_zip->add( name = lv_name
                 content = lv_data ).


    FREE: lo_client.
    CLEAR lt_str.

  ENDLOOP.


  DATA(lv_zip_xstring) = lo_zip->save( ).


* Convert the XSTRING to Binary table
  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer        = lv_zip_xstring
    IMPORTING
      output_length = lv_zip_size
    TABLES
      binary_tab    = lt_zip_bin_data.



  CALL METHOD cl_gui_frontend_services=>file_save_dialog
    EXPORTING
      window_title              = 'Select the File Save Location'
      file_filter               = '(*.zip)|*.zip|'
    CHANGING
      filename                  = lv_filename              " File Name to Save
      path                      = lv_path                " Path to File
      fullpath                  = lv_fullpath              " Path + File Name
    EXCEPTIONS
      cntl_error                = 1                " Control error
      error_no_gui              = 2                " No GUI available
      not_supported_by_gui      = 3                " GUI does not support this
      invalid_default_file_name = 4                " Invalid default file name
      OTHERS                    = 5.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

* Download the Zip file
  cl_gui_frontend_services=>gui_download(
    EXPORTING
      bin_filesize              = lv_zip_size
      filename                  = lv_fullpath
      filetype                  = 'BIN'
    CHANGING
      data_tab                  = lt_zip_bin_data
    EXCEPTIONS
      file_write_error          = 1
      no_batch                  = 2
      gui_refuse_filetransfer   = 3
      invalid_type              = 4
      no_authority              = 5
      unknown_error             = 6
      header_not_allowed        = 7
      separator_not_allowed     = 8
      filesize_not_allowed      = 9
      header_too_long           = 10
      dp_error_create           = 11
      dp_error_send             = 12
      dp_error_write            = 13
      unknown_dp_error          = 14
      access_denied             = 15
      dp_out_of_memory          = 16
      disk_full                 = 17
      dp_timeout                = 18
      file_not_found            = 19
      dataprovider_exception    = 20
      control_flush_error       = 21
      not_supported_by_gui      = 22
      error_no_gui              = 23
      OTHERS                    = 24
         ).
