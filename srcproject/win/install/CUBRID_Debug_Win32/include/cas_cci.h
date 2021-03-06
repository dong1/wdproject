/*
 * Copyright (C) 2008 Search Solution Corporation. All rights reserved by Search Solution.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * - Neither the name of the <ORGANIZATION> nor the names of its contributors
 *   may be used to endorse or promote products derived from this software without
 *   specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 */

/*
 * cas_cci.h -
 */

#ifndef	_CAS_CCI_H_
#define	_CAS_CCI_H_

#ident "$Id$"

#include "cas_error.h"

#ifdef __cplusplus
extern "C"
{
#endif

/************************************************************************
 * IMPORTED SYSTEM HEADER FILES						*
 ************************************************************************/

/************************************************************************
 * IMPORTED OTHER HEADER FILES						*
 ************************************************************************/

/************************************************************************
 * EXPORTED DEFINITIONS							*
 ************************************************************************/

#define CCI_GET_RESULT_INFO_TYPE(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].type)

#define CCI_GET_RESULT_INFO_SCALE(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].scale)

#define CCI_GET_RESULT_INFO_PRECISION(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].precision)

#define CCI_GET_RESULT_INFO_NAME(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].col_name)

#define CCI_GET_RESULT_INFO_ATTR_NAME(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].real_attr)

#define CCI_GET_RESULT_INFO_CLASS_NAME(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].class_name)

#define CCI_GET_RESULT_INFO_IS_NON_NULL(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].is_non_null)

#define CCI_GET_RESULT_INFO_DEFAULT_VALUE(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].default_value)

#define CCI_GET_RESULT_INFO_IS_AUTO_INCREMENT(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].is_auto_increment)

#define CCI_GET_RESULT_INFO_IS_UNIQUE_KEY(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].is_unique_key)

#define CCI_GET_RESULT_INFO_IS_PRIMARY_KEY(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].is_primary_key)

#define CCI_GET_RESULT_INFO_IS_FOREIGN_KEY(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].is_foreign_key)

#define CCI_GET_RESULT_INFO_IS_REVERSE_INDEX(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].is_reverse_index)

#define CCI_GET_RESULT_INFO_IS_REVERSE_UNIQUE(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].is_reverse_unique)

#define CCI_GET_RESULT_INFO_IS_SHARED(RES_INFO, INDEX)	\
		(((T_CCI_COL_INFO*) (RES_INFO))[(INDEX) - 1].is_shared)

#define CCI_IS_SET_TYPE(TYPE)	\
	(((((TYPE) & CCI_CODE_COLLECTION) == CCI_CODE_SET) || ((TYPE) == CCI_U_TYPE_SET)) ? 1 : 0)

#define CCI_IS_MULTISET_TYPE(TYPE)	\
	(((((TYPE) & CCI_CODE_COLLECTION) == CCI_CODE_MULTISET) || ((TYPE) == CCI_U_TYPE_MULTISET)) ? 1 : 0)

#define CCI_IS_SEQUENCE_TYPE(TYPE)	\
	(((((TYPE) & CCI_CODE_COLLECTION) == CCI_CODE_SEQUENCE) || ((TYPE) == CCI_U_TYPE_SEQUENCE)) ? 1 : 0)

#define CCI_IS_COLLECTION_TYPE(TYPE)	\
	((((TYPE) & CCI_CODE_COLLECTION) || ((TYPE) == CCI_U_TYPE_SET) || ((TYPE) == CCI_U_TYPE_MULTISET) || ((TYPE) == CCI_U_TYPE_SEQUENCE)) ? 1 : 0)

#define CCI_GET_COLLECTION_DOMAIN(TYPE)	(~(CCI_CODE_COLLECTION) & (TYPE))

#define CCI_QUERY_RESULT_RESULT(QR, INDEX)	\
	(((T_CCI_QUERY_RESULT*) (QR))[(INDEX) - 1].result_count)

#define CCI_QUERY_RESULT_ERR_MSG(QR, INDEX)	\
	((((T_CCI_QUERY_RESULT*) (QR))[(INDEX) - 1].err_msg) == NULL ? "" : (((T_CCI_QUERY_RESULT*) (QR))[(INDEX) - 1].err_msg))

#define CCI_QUERY_RESULT_STMT_TYPE(QR, INDEX)	\
	(((T_CCI_QUERY_RESULT*) (QR))[(INDEX) - 1].stmt_type)

#define CCI_QUERY_RESULT_OID(QR, INDEX)	\
	(((T_CCI_QUERY_RESULT*) (QR))[(INDEX) - 1].oid)

#define CCI_GET_PARAM_INFO_MODE(PARAM_INFO, INDEX)	\
	(((T_CCI_PARAM_INFO*) (PARAM_INFO))[(INDEX) - 1].mode)
#define CCI_GET_PARAM_INFO_TYPE(PARAM_INFO, INDEX)	\
	(((T_CCI_PARAM_INFO*) (PARAM_INFO))[(INDEX) - 1].type)
#define CCI_GET_PARAM_INFO_SCALE(PARAM_INFO, INDEX)	\
	(((T_CCI_PARAM_INFO*) (PARAM_INFO))[(INDEX) - 1].scale)
#define CCI_GET_PARAM_INFO_PRECISION(PARAM_INFO, INDEX)	\
	(((T_CCI_PARAM_INFO*) (PARAM_INFO))[(INDEX) - 1].precision)

#define CCI_BIND_PTR			1

#define CCI_TRAN_COMMIT			1
#define CCI_TRAN_ROLLBACK		2

#define CCI_PREPARE_INCLUDE_OID		0x01
#define CCI_PREPARE_UPDATABLE		0x02
#define CCI_PREPARE_CALL		0x40

#define CCI_EXEC_ASYNC			0x01
#define CCI_EXEC_QUERY_ALL		0x02
#define CCI_EXEC_QUERY_INFO		0x04
#define CCI_EXEC_ONLY_QUERY_PLAN        0x08
#define CCI_EXEC_THREAD			0x10

#define CCI_FETCH_SENSITIVE		1

#define CCI_CLASS_NAME_PATTERN_MATCH	1
#define CCI_ATTR_NAME_PATTERN_MATCH	2

#define CCI_CODE_SET			0x20
#define CCI_CODE_MULTISET		0x40
#define CCI_CODE_SEQUENCE		0x60
#define CCI_CODE_COLLECTION		0x60

#define CCI_LOCK_TIMEOUT_INFINITE	-1
#define CCI_LOCK_TIMEOUT_DEFAULT	-2

#define CCI_CLOSE_CURRENT_RESULT	0
#define CCI_KEEP_CURRENT_RESULT		1

#define CCI_CONNECT_INTERNAL_FUNC_NAME	cci_connect_3_0
#define cci_connect(IP,PORT,DBNAME,DBUSER,DBPASSWD)	\
	CCI_CONNECT_INTERNAL_FUNC_NAME(IP,PORT,DBNAME,DBUSER,DBPASSWD)

#define CCI_DBMS_CUBRID			1
#define CCI_DBMS_CUBRID_MMDB		2

/* schema_info CONSTRAINT */
#define CCI_CONSTRAINT_TYPE_UNIQUE	0
#define CCI_CONSTRAINT_TYPE_INDEX	1

#if defined(WINDOWS)
#define SSIZEOF(val) ((SSIZE_T) sizeof(val))
#else
#define SSIZEOF(val) ((ssize_t) sizeof(val))
#endif

/* for cci auto_comit mode support */
  enum
  {
    CCI_AUTOCOMMIT_FALSE = 0,
    CCI_AUTOCOMMIT_TRUE
  };

/************************************************************************
 * EXPORTED TYPE DEFINITIONS						*
 ************************************************************************/

  typedef struct
  {
    int err_code;
    char err_msg[1024];
  } T_CCI_ERROR;

  typedef struct
  {
    int size;
    char *buf;
  } T_CCI_BIT;

  typedef struct
  {
    short yr;
    short mon;
    short day;
    short hh;
    short mm;
    short ss;
    short ms;
  } T_CCI_DATE;

  typedef struct
  {
    int result_count;
    int stmt_type;
    char *err_msg;
    char oid[32];
  } T_CCI_QUERY_RESULT;

  typedef enum
  {
    CCI_U_TYPE_FIRST = 0,
    CCI_U_TYPE_UNKNOWN = 0,
    CCI_U_TYPE_NULL = 0,

    CCI_U_TYPE_CHAR = 1,
    CCI_U_TYPE_STRING = 2,
    CCI_U_TYPE_NCHAR = 3,
    CCI_U_TYPE_VARNCHAR = 4,
    CCI_U_TYPE_BIT = 5,
    CCI_U_TYPE_VARBIT = 6,
    CCI_U_TYPE_NUMERIC = 7,
    CCI_U_TYPE_INT = 8,
    CCI_U_TYPE_SHORT = 9,
    CCI_U_TYPE_MONETARY = 10,
    CCI_U_TYPE_FLOAT = 11,
    CCI_U_TYPE_DOUBLE = 12,
    CCI_U_TYPE_DATE = 13,
    CCI_U_TYPE_TIME = 14,
    CCI_U_TYPE_TIMESTAMP = 15,
    CCI_U_TYPE_SET = 16,
    CCI_U_TYPE_MULTISET = 17,
    CCI_U_TYPE_SEQUENCE = 18,
    CCI_U_TYPE_OBJECT = 19,
    CCI_U_TYPE_RESULTSET = 20,
    CCI_U_TYPE_BIGINT = 21,
    CCI_U_TYPE_DATETIME = 22,

    CCI_U_TYPE_LAST = CCI_U_TYPE_DATETIME
  } T_CCI_U_TYPE;

  typedef void *T_CCI_SET;

  typedef enum
  {
    CCI_A_TYPE_FIRST = 1,
    CCI_A_TYPE_STR = 1,
    CCI_A_TYPE_INT,
    CCI_A_TYPE_FLOAT,
    CCI_A_TYPE_DOUBLE,
    CCI_A_TYPE_BIT,
    CCI_A_TYPE_DATE,
    CCI_A_TYPE_SET,
    CCI_A_TYPE_BIGINT,
    CCI_A_TYPE_LAST = CCI_A_TYPE_BIGINT,

    CCI_A_TYTP_LAST = CCI_A_TYPE_LAST	/* typo but backward compatibility */
  } T_CCI_A_TYPE;

  typedef enum
  {
    CCI_PARAM_FIRST = 1,
    CCI_PARAM_ISOLATION_LEVEL = 1,
    CCI_PARAM_LOCK_TIMEOUT = 2,
    CCI_PARAM_MAX_STRING_LENGTH = 3,
    CCI_PARAM_AUTO_COMMIT = 4,
    CCI_PARAM_LAST = CCI_PARAM_AUTO_COMMIT
  } T_CCI_DB_PARAM;

  typedef enum
  {
    CCI_SCH_FIRST = 1,
    CCI_SCH_CLASS = 1,
    CCI_SCH_VCLASS,
    CCI_SCH_QUERY_SPEC,
    CCI_SCH_ATTRIBUTE,
    CCI_SCH_CLASS_ATTRIBUTE,
    CCI_SCH_METHOD,
    CCI_SCH_CLASS_METHOD,
    CCI_SCH_METHOD_FILE,
    CCI_SCH_SUPERCLASS,
    CCI_SCH_SUBCLASS,
    CCI_SCH_CONSTRAINT,
    CCI_SCH_TRIGGER,
    CCI_SCH_CLASS_PRIVILEGE,
    CCI_SCH_ATTR_PRIVILEGE,
    CCI_SCH_DIRECT_SUPER_CLASS,
    CCI_SCH_PRIMARY_KEY,
    CCI_SCH_LAST = CCI_SCH_PRIMARY_KEY
  } T_CCI_SCH_TYPE;

  typedef enum
  {
    CCI_ER_NO_ERROR = 0,
    CCI_ER_DBMS = -1,
    CCI_ER_CON_HANDLE = -2,
    CCI_ER_NO_MORE_MEMORY = -3,
    CCI_ER_COMMUNICATION = -4,
    CCI_ER_NO_MORE_DATA = -5,
    CCI_ER_TRAN_TYPE = -6,
    CCI_ER_STRING_PARAM = -7,
    CCI_ER_TYPE_CONVERSION = -8,
    CCI_ER_BIND_INDEX = -9,
    CCI_ER_ATYPE = -10,
    CCI_ER_NOT_BIND = -11,
    CCI_ER_PARAM_NAME = -12,
    CCI_ER_COLUMN_INDEX = -13,
    CCI_ER_SCHEMA_TYPE = -14,
    CCI_ER_FILE = -15,
    CCI_ER_CONNECT = -16,

    CCI_ER_ALLOC_CON_HANDLE = -17,
    CCI_ER_REQ_HANDLE = -18,
    CCI_ER_INVALID_CURSOR_POS = -19,
    CCI_ER_OBJECT = -20,
    CCI_ER_CAS = -21,
    CCI_ER_HOSTNAME = -22,
    CCI_ER_OID_CMD = -23,

    CCI_ER_BIND_ARRAY_SIZE = -24,
    CCI_ER_ISOLATION_LEVEL = -25,

    CCI_ER_SET_INDEX = -26,
    CCI_ER_DELETED_TUPLE = -27,

    CCI_ER_SAVEPOINT_CMD = -28,
    CCI_ER_THREAD_RUNNING = -29,
    CCI_ER_INVALID_URL = -30,

    CCI_ER_NOT_IMPLEMENTED = -99
  } T_CCI_ERROR_CODE;

#if !defined(CAS)
#ifdef DBDEF_HEADER_
  typedef int T_CCI_CUBRID_STMT;
#else
  typedef enum
  {
    CUBRID_STMT_ALTER_CLASS,
    CUBRID_STMT_ALTER_SERIAL,
    CUBRID_STMT_COMMIT_WORK,
    CUBRID_STMT_REGISTER_DATABASE,
    CUBRID_STMT_CREATE_CLASS,
    CUBRID_STMT_CREATE_INDEX,
    CUBRID_STMT_CREATE_TRIGGER,
    CUBRID_STMT_CREATE_SERIAL,
    CUBRID_STMT_DROP_DATABASE,
    CUBRID_STMT_DROP_CLASS,
    CUBRID_STMT_DROP_INDEX,
    CUBRID_STMT_DROP_LABEL,
    CUBRID_STMT_DROP_TRIGGER,
    CUBRID_STMT_DROP_SERIAL,
    CUBRID_STMT_EVALUATE,
    CUBRID_STMT_RENAME_CLASS,
    CUBRID_STMT_ROLLBACK_WORK,
    CUBRID_STMT_GRANT,
    CUBRID_STMT_REVOKE,
    CUBRID_STMT_STATISTICS,
    CUBRID_STMT_INSERT,
    CUBRID_STMT_SELECT,
    CUBRID_STMT_UPDATE,
    CUBRID_STMT_DELETE,
    CUBRID_STMT_CALL,
    CUBRID_STMT_GET_ISO_LVL,
    CUBRID_STMT_GET_TIMEOUT,
    CUBRID_STMT_GET_OPT_LVL,
    CUBRID_STMT_SET_OPT_LVL,
    CUBRID_STMT_SCOPE,
    CUBRID_STMT_GET_TRIGGER,
    CUBRID_STMT_SET_TRIGGER,
    CUBRID_STMT_SAVEPOINT,
    CUBRID_STMT_PREPARE,
    CUBRID_STMT_ATTACH,
    CUBRID_STMT_USE,
    CUBRID_STMT_REMOVE_TRIGGER,
    CUBRID_STMT_RENAME_TRIGGER,
    CUBRID_STMT_ON_LDB,
    CUBRID_STMT_GET_LDB,
    CUBRID_STMT_SET_LDB,

    CUBRID_STMT_GET_STATS,
    CUBRID_STMT_CREATE_USER,
    CUBRID_STMT_DROP_USER,
    CUBRID_STMT_ALTER_USER
  } T_CCI_CUBRID_STMT;
#endif
#endif
#define CUBRID_STMT_CALL_SP	0x7e
#define CUBRID_STMT_UNKNOWN	0x7f

/* for backward compatibility */
#define T_CCI_SQLX_CMD T_CCI_CUBRID_STMT

#define SQLX_CMD_ALTER_CLASS   CUBRID_STMT_ALTER_CLASS
#define SQLX_CMD_ALTER_SERIAL   CUBRID_STMT_ALTER_SERIAL
#define SQLX_CMD_COMMIT_WORK   CUBRID_STMT_COMMIT_WORK
#define SQLX_CMD_REGISTER_DATABASE   CUBRID_STMT_REGISTER_DATABASE
#define SQLX_CMD_CREATE_CLASS   CUBRID_STMT_CREATE_CLASS
#define SQLX_CMD_CREATE_INDEX   CUBRID_STMT_CREATE_INDEX
#define SQLX_CMD_CREATE_TRIGGER   CUBRID_STMT_CREATE_TRIGGER
#define SQLX_CMD_CREATE_SERIAL   CUBRID_STMT_CREATE_SERIAL
#define SQLX_CMD_DROP_DATABASE   CUBRID_STMT_DROP_DATABASE
#define SQLX_CMD_DROP_CLASS   CUBRID_STMT_DROP_CLASS
#define SQLX_CMD_DROP_INDEX   CUBRID_STMT_DROP_INDEX
#define SQLX_CMD_DROP_LABEL   CUBRID_STMT_DROP_LABEL
#define SQLX_CMD_DROP_TRIGGER   CUBRID_STMT_DROP_TRIGGER
#define SQLX_CMD_DROP_SERIAL   CUBRID_STMT_DROP_SERIAL
#define SQLX_CMD_EVALUATE   CUBRID_STMT_EVALUATE
#define SQLX_CMD_RENAME_CLASS   CUBRID_STMT_RENAME_CLASS
#define SQLX_CMD_ROLLBACK_WORK   CUBRID_STMT_ROLLBACK_WORK
#define SQLX_CMD_GRANT   CUBRID_STMT_GRANT
#define SQLX_CMD_REVOKE   CUBRID_STMT_REVOKE
#define SQLX_CMD_UPDATE_STATS   CUBRID_STMT_UPDATE_STATS
#define SQLX_CMD_INSERT   CUBRID_STMT_INSERT
#define SQLX_CMD_SELECT   CUBRID_STMT_SELECT
#define SQLX_CMD_UPDATE   CUBRID_STMT_UPDATE
#define SQLX_CMD_DELETE   CUBRID_STMT_DELETE
#define SQLX_CMD_CALL   CUBRID_STMT_CALL
#define SQLX_CMD_GET_ISO_LVL   CUBRID_STMT_GET_ISO_LVL
#define SQLX_CMD_GET_TIMEOUT   CUBRID_STMT_GET_TIMEOUT
#define SQLX_CMD_GET_OPT_LVL   CUBRID_STMT_GET_OPT_LVL
#define SQLX_CMD_SET_OPT_LVL   CUBRID_STMT_SET_OPT_LVL
#define SQLX_CMD_SCOPE   CUBRID_STMT_SCOPE
#define SQLX_CMD_GET_TRIGGER   CUBRID_STMT_GET_TRIGGER
#define SQLX_CMD_SET_TRIGGER   CUBRID_STMT_SET_TRIGGER
#define SQLX_CMD_SAVEPOINT   CUBRID_STMT_SAVEPOINT
#define SQLX_CMD_PREPARE   CUBRID_STMT_PREPARE
#define SQLX_CMD_ATTACH   CUBRID_STMT_ATTACH
#define SQLX_CMD_USE   CUBRID_STMT_USE
#define SQLX_CMD_REMOVE_TRIGGER   CUBRID_STMT_REMOVE_TRIGGER
#define SQLX_CMD_RENMAE_TRIGGER   CUBRID_STMT_RENAME_TRIGGER
#define SQLX_CMD_ON_LDB   CUBRID_STMT_ON_LDB
#define SQLX_CMD_GET_LDB   CUBRID_STMT_GET_LDB
#define SQLX_CMD_SET_LDB   CUBRID_STMT_SET_LDB
#define SQLX_CMD_GET_STATS   CUBRID_STMT_GET_STATS
#define SQLX_CMD_CREATE_USER   CUBRID_STMT_CREATE_USER
#define SQLX_CMD_DROP_USER   CUBRID_STMT_DROP_USER
#define SQLX_CMD_ALTER_USER   CUBRID_STMT_ALTER_USER
#define SQLX_CMD_SET_SYS_PARAMS   CUBRID_STMT_SET_SYS_PARAMS
#define SQLX_CMD_ALTER_INDEX   CUBRID_STMT_ALTER_INDEX
#define SQLX_CMD_CREATE_STORED_PROCEDURE   CUBRID_STMT_CREATE_STORED_PROCEDURE
#define SQLX_CMD_DROP_STORED_PROCEDURE   CUBRID_STMT_DROP_STORED_PROCEDURE
#define SQLX_CMD_SELECT_UPDATE   CUBRID_STMT_SELECT_UPDATE
#define SQLX_MAX_CMD_TYPE   CUBRID_MAX_STMT_TYPE

#define SQLX_CMD_CALL_SP CUBRID_STMT_CALL_SP
#define SQLX_CMD_UNKNOWN CUBRID_STMT_UNKNOWN

  typedef enum
  {
    CCI_CURSOR_FIRST = 0,
    CCI_CURSOR_CURRENT = 1,
    CCI_CURSOR_LAST = 2
  } T_CCI_CURSOR_POS;

  typedef struct
  {
    T_CCI_U_TYPE type;
    char is_non_null;
    short scale;
    int precision;
    char *col_name;
    char *real_attr;
    char *class_name;
    char *default_value;
    char is_auto_increment;
    char is_unique_key;
    char is_primary_key;
    char is_foreign_key;
    char is_reverse_index;
    char is_reverse_unique;
    char is_shared;
  } T_CCI_COL_INFO;

  typedef enum
  {
    CCI_OID_CMD_FIRST = 1,

    CCI_OID_DROP = 1,
    CCI_OID_IS_INSTANCE = 2,
    CCI_OID_LOCK_READ = 3,
    CCI_OID_LOCK_WRITE = 4,
    CCI_OID_CLASS_NAME = 5,
    CCI_OID_IS_GLO_INSTANCE = 6,

    CCI_OID_CMD_LAST = CCI_OID_IS_GLO_INSTANCE
  } T_CCI_OID_CMD;

  typedef enum
  {
    CCI_COL_CMD_FIRST = 1,
    CCI_COL_GET = 1,
    CCI_COL_SIZE = 2,
    CCI_COL_SET_DROP = 3,
    CCI_COL_SET_ADD = 4,
    CCI_COL_SEQ_DROP = 5,
    CCI_COL_SEQ_INSERT = 6,
    CCI_COL_SEQ_PUT = 7,
    CCI_COL_CMD_LAST = CCI_COL_SEQ_PUT
  } T_CCI_COLLECTION_CMD;

  typedef enum
  {
    CCI_SP_CMD_FIRST = 1,
    CCI_SP_SET = 1,
    CCI_SP_ROLLBACK = 2,
    CCI_SP_CMD_LAST = CCI_SP_ROLLBACK
  } T_CCI_SAVEPOINT_CMD;

#if !defined(CAS)
#ifdef DBDEF_HEADER_
  typedef int T_CCI_TRAN_ISOLATION;
#else
  typedef enum
  {
    TRAN_ISOLATION_MIN = 1,

    TRAN_COMMIT_CLASS_UNCOMMIT_INSTANCE = 1,
    TRAN_COMMIT_CLASS_COMMIT_INSTANCE = 2,
    TRAN_REP_CLASS_UNCOMMIT_INSTANCE = 3,
    TRAN_REP_CLASS_COMMIT_INSTANCE = 4,
    TRAN_REP_CLASS_REP_INSTANCE = 5,
    TRAN_SERIALIZABLE = 6,

    TRAN_ISOLATION_MAX = 6
  } T_CCI_TRAN_ISOLATION;
#endif
#endif

  typedef enum
  {
    CCI_PARAM_MODE_UNKNOWN = 0,
    CCI_PARAM_MODE_IN = 1,
    CCI_PARAM_MODE_OUT = 2,
    CCI_PARAM_MODE_INOUT = 3
  } T_CCI_PARAM_MODE;

  typedef struct
  {
    T_CCI_PARAM_MODE mode;
    T_CCI_U_TYPE type;
    short scale;
    int precision;
  } T_CCI_PARAM_INFO;

/************************************************************************
 * EXPORTED FUNCTION PROTOTYPES						*
 ************************************************************************/

#if !defined(CAS)

  extern void cci_init (void);
  extern void cci_end (void);

  extern int cci_get_version (int *major, int *minor, int *patch);
  extern int CCI_CONNECT_INTERNAL_FUNC_NAME (char *ip,
					     int port,
					     char *db_name,
					     char *db_user, char *dbpasswd);
  extern int cci_connect_with_url (char *url, char *user, char *password);
  extern int cci_disconnect (int con_handle, T_CCI_ERROR * err_buf);
  extern int cci_end_tran (int con_handle, char type, T_CCI_ERROR * err_buf);
  extern int cci_prepare (int con_handle,
			  char *sql_stmt, char flag, T_CCI_ERROR * err_buf);
  extern int cci_get_bind_num (int req_handle);
  extern T_CCI_COL_INFO *cci_get_result_info (int req_handle,
					      T_CCI_CUBRID_STMT * cmd_type,
					      int *num);
  extern int cci_bind_param (int req_handle,
			     int index,
			     T_CCI_A_TYPE a_type,
			     void *value, T_CCI_U_TYPE u_type, char flag);
  extern int cci_execute (int req_handle,
			  char flag, int max_col_size, T_CCI_ERROR * err_buf);
  extern int cci_get_db_parameter (int con_handle, T_CCI_DB_PARAM param_name,
				   void *value, T_CCI_ERROR * err_buf);
  extern int cci_set_db_parameter (int con_handle, T_CCI_DB_PARAM param_name,
				   void *value, T_CCI_ERROR * err_buf);
  extern int cci_close_req_handle (int req_handle);
  extern int cci_cursor (int req_handle,
			 int offset,
			 T_CCI_CURSOR_POS origin, T_CCI_ERROR * err_buf);
  extern int cci_fetch_size (int req_handle, int fetch_size);
  extern int cci_fetch (int req_handle, T_CCI_ERROR * err_buf);
  extern int cci_get_data (int req_handle,
			   int col_no, int type, void *value, int *indicator);
  extern int cci_schema_info (int con_handle,
			      T_CCI_SCH_TYPE type,
			      char *class_name,
			      char *attr_name,
			      char flag, T_CCI_ERROR * err_buf);
  extern int cci_get_cur_oid (int req_handle, char *oid_str_buf);
  extern int cci_oid_get (int con_handle,
			  char *oid_str,
			  char **attr_name, T_CCI_ERROR * err_buf);
  extern int cci_oid_put (int con_handle,
			  char *oid_str,
			  char **attr_name,
			  char **new_val, T_CCI_ERROR * err_buf);
  extern int cci_oid_put2 (int con_h_id,
			   char *oid_str,
			   char **attr_name,
			   void **new_val,
			   int *a_type, T_CCI_ERROR * err_buf);
  extern int cci_glo_new (int con_handle,
			  char *class_name,
			  char *filename,
			  char *oid_str, T_CCI_ERROR * err_buf);
  extern int cci_glo_save (int con_handle,
			   char *oid_str,
			   char *filename, T_CCI_ERROR * err_buf);
  extern int cci_glo_load (int con_handle,
			   char *oid_str, int out_fd, T_CCI_ERROR * err_buf);
  extern int cci_glo_load_file_name (int con_handle, char *oid_str,
				     char *out_filename,
				     T_CCI_ERROR * err_buf);
  extern int cci_get_db_version (int con_handle, char *out_buf, int buf_size);
  extern int cci_get_class_num_objs (int conn_handle,
				     char *class_name,
				     int flag,
				     int *num_objs,
				     int *num_pages, T_CCI_ERROR * err_buf);
  extern int cci_oid (int con_h_id,
		      T_CCI_OID_CMD cmd,
		      char *oid_str, T_CCI_ERROR * err_buf);
  extern int cci_oid_get_class_name (int con_h_id,
				     char *oid_str,
				     char *out_buf,
				     int out_buf_len, T_CCI_ERROR * err_buf);
  extern int cci_col_get (int con_h_id,
			  char *oid_str,
			  char *col_attr,
			  int *col_size,
			  int *col_type, T_CCI_ERROR * err_buf);
  extern int cci_col_size (int con_h_id,
			   char *oid_str,
			   char *col_attr,
			   int *col_size, T_CCI_ERROR * err_buf);
  extern int cci_col_set_drop (int con_h_id,
			       char *oid_str,
			       char *col_attr,
			       char *value, T_CCI_ERROR * err_buf);
  extern int cci_col_set_add (int con_h_id,
			      char *oid_str,
			      char *col_attr,
			      char *value, T_CCI_ERROR * err_buf);
  extern int cci_col_seq_drop (int con_h_id,
			       char *oid_str,
			       char *col_attr,
			       int index, T_CCI_ERROR * err_buf);
  extern int cci_col_seq_insert (int con_h_id,
				 char *oid_str,
				 char *col_attr,
				 int index,
				 char *value, T_CCI_ERROR * err_buf);
  extern int cci_col_seq_put (int con_h_id,
			      char *oid_str,
			      char *col_attr,
			      int index, char *value, T_CCI_ERROR * err_buf);

  extern int cci_is_updatable (int req_h_id);
  extern int cci_next_result (int req_h_id, T_CCI_ERROR * err_buf);
  extern int cci_bind_param_array_size (int req_h_id, int array_size);
  extern int cci_bind_param_array (int req_h_id,
				   int index,
				   T_CCI_A_TYPE a_type,
				   void *value,
				   int *null_ind, T_CCI_U_TYPE u_type);
  extern int cci_execute_array (int req_h_id,
				T_CCI_QUERY_RESULT ** qr,
				T_CCI_ERROR * err_buf);
  extern int cci_query_result_free (T_CCI_QUERY_RESULT * qr, int num_q);
  extern int cci_fetch_sensitive (int req_h_id, T_CCI_ERROR * err_buf);
  extern int cci_cursor_update (int req_h_id,
				int cursor_pos,
				int index,
				T_CCI_A_TYPE a_type,
				void *value, T_CCI_ERROR * err_buf);
  extern int cci_execute_batch (int con_h_id,
				int num_query,
				char **sql_stmt,
				T_CCI_QUERY_RESULT ** qr,
				T_CCI_ERROR * err_buf);
  extern int cci_fetch_buffer_clear (int req_h_id);
  extern int cci_execute_result (int req_h_id,
				 T_CCI_QUERY_RESULT ** qr,
				 T_CCI_ERROR * err_buf);
  extern int cci_set_isolation_level (int con_id,
				      T_CCI_TRAN_ISOLATION val,
				      T_CCI_ERROR * err_buf);

  extern void cci_set_free (T_CCI_SET set);
  extern int cci_set_size (T_CCI_SET set);
  extern int cci_set_element_type (T_CCI_SET set);
  extern int cci_set_get (T_CCI_SET set,
			  int index,
			  T_CCI_A_TYPE a_type, void *value, int *indicator);
  extern int cci_set_make (T_CCI_SET * set,
			   T_CCI_U_TYPE u_type,
			   int size, void *value, int *indicator);
  extern int cci_get_attr_type_str (int con_h_id,
				    char *class_name,
				    char *attr_name,
				    char *buf,
				    int buf_size, T_CCI_ERROR * err_buf);
  extern int cci_get_query_plan (int req_h_id, char **out_buf);
  extern int cci_get_query_histogram (int req_h_id, char **out_buf);
  extern int cci_query_info_free (char *out_buf);
  extern int cci_set_max_row (int req_h_id, int max_row);
  extern int cci_savepoint (int con_h_id,
			    T_CCI_SAVEPOINT_CMD cmd,
			    char *savepoint_name, T_CCI_ERROR * err_buf);
  extern int cci_get_param_info (int req_handle,
				 T_CCI_PARAM_INFO ** param,
				 T_CCI_ERROR * err_buf);
  extern int cci_param_info_free (T_CCI_PARAM_INFO * param);

  extern int cci_glo_read_data (int con_h_id, char *oid_str,
				int start_pos, int length, char *buf,
				T_CCI_ERROR * err_buf);
  extern int cci_glo_write_data (int con_h_id, char *oid_str,
				 int start_pos, int length, char *buf,
				 T_CCI_ERROR * err_buf);
  extern int cci_glo_insert_data (int con_h_id, char *oid_str,
				  int start_pos, int length, char *buf,
				  T_CCI_ERROR * err_buf);
  extern int cci_glo_delete_data (int con_h_id, char *oid_str,
				  int start_pos, int length,
				  T_CCI_ERROR * err_buf);
  extern int cci_glo_truncate_data (int con_h_id, char *oid_str,
				    int start_pos, T_CCI_ERROR * err_buf);
  extern int cci_glo_append_data (int con_h_id, char *oid_str,
				  int length, char *buf,
				  T_CCI_ERROR * err_buf);
  extern int cci_glo_data_size (int con_h_id, char *oid_str,
				T_CCI_ERROR * err_buf);
  extern int cci_glo_compress_data (int con_h_id, char *oid_str,
				    T_CCI_ERROR * err_buf);
  extern int cci_glo_destroy_data (int con_h_id, char *oid_str,
				   T_CCI_ERROR * err_buf);
  extern int cci_glo_like_search (int con_h_id, char *oid_str,
				  int start_pos, char *search_str,
				  int *offset, int *cur_pos,
				  T_CCI_ERROR * err_buf);
  extern int cci_glo_reg_search (int con_h_id, char *oid_str,
				 int start_pos, char *search_str,
				 int *offset, int *cur_pos,
				 T_CCI_ERROR * err_buf);
  extern int cci_glo_binary_search (int con_h_id, char *oid_str,
				    int start_pos,
				    int length, char *search_array,
				    int *offset, int *cur_pos,
				    T_CCI_ERROR * err_buf);
  extern int cci_get_dbms_type (int con_h_id);
  extern int cci_register_out_param (int req_h_id, int index);
  extern int cci_cancel (int con_h_id);
  extern int cci_get_thread_result (int con_id, T_CCI_ERROR * err_buf);
  extern int cci_get_error_msg (int err_code, T_CCI_ERROR * err_buf,
				char *out_buf, int out_buf_size);
  extern int cci_get_err_msg (int err_code, char *buf, int bufsize);
#endif

/************************************************************************
 * EXPORTED VARIABLES							*
 ************************************************************************/

#ifdef __cplusplus
}
#endif

#endif				/* _CAS_CCI_H_ */
