/* vim: set fdc=3 fdm=marker: */

/*
 * Copyright (C) 2008 Search Solution Corporation. All rights reserved by Search Solution.
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

/*
 * csql_grammar.y - SQL grammar file
 */



%{
#define YYMAXDEPTH	1000000

/* #define PARSER_DEBUG */

#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <errno.h>

#include "parser.h"
#include "parser_message.h"
#include "dbdef.h"
#include "language_support.h"
#include "environment_variable.h"
#include "transaction_cl.h"
#include "csql_grammar_scan.h"
#include "system_parameter.h"
#define JP_MAXNAME 256
#if defined(WINDOWS)
#define snprintf _snprintf
#endif /* WINDOWS */
#include "memory_alloc.h"

/* Bit mask to be used to check constraints of a column.
 * COLUMN_CONSTRAINT_SHARED_DEFAULT_AI is special-purpose mask
 * to identify duplication of SHARED, DEFAULT and AUTO_INCREMENT.
 */
#define COLUMN_CONSTRAINT_UNIQUE		(0x01)
#define COLUMN_CONSTRAINT_PRIMARY_KEY		(0x02)
#define COLUMN_CONSTRAINT_NULL			(0x04)
#define COLUMN_CONSTRAINT_OTHERS		(0x08)
#define COLUMN_CONSTRAINT_SHARED		(0x10)
#define COLUMN_CONSTRAINT_DEFAULT		(0x20)
#define COLUMN_CONSTRAINT_AUTO_INCREMENT	(0x40)

#define COLUMN_CONSTRAINT_SHARED_DEFAULT_AI	(0x70)


#ifdef PARSER_DEBUG
#define DBG_PRINT printf("rule matched at line: %d\n", __LINE__);
#define PRINT_(a) printf(a)
#define PRINT_1(a, b) printf(a, b)
#define PRINT_2(a, b, c) printf(a, b, c)
#else
#define DBG_PRINT
#define PRINT_(a)
#define PRINT_1(a, b)
#define PRINT_2(a, b, c)
#endif

#define STACK_SIZE	128

typedef struct function_map FUNCTION_MAP;
struct function_map
{
  const char* keyword;
  PT_OP_TYPE op;
};


static FUNCTION_MAP functions[] = {
  {"abs", PT_ABS},
  {"acos", PT_ACOS},
  {"asin", PT_ASIN},
  {"atan", PT_ATAN},
  {"atan2", PT_ATAN2},
  {"bit_count", PT_BIT_COUNT},
  {"ceil", PT_CEIL},
  {"ceiling", PT_CEIL},
  {"char_length", PT_CHAR_LENGTH},
  {"character_length", PT_CHAR_LENGTH},
  {"chr", PT_CHR},
  {"concat", PT_CONCAT},
  {"concat_ws", PT_CONCAT_WS},
  {"cos", PT_COS},
  {"cot", PT_COT},
  {"curtime", PT_SYS_TIME},
  {"curdate", PT_SYS_DATE},
  {"datediff", PT_DATEDIFF},
  {"date_format", PT_DATE_FORMAT},
  {"decode", PT_DECODE},
  {"decr", PT_DECR},
  {"degrees", PT_DEGREES},
  {"drand", PT_DRAND},
  {"drandom", PT_DRANDOM},
  {"exp", PT_EXP},
  {"field", PT_FIELD},
  {"floor", PT_FLOOR},
  {"greatest", PT_GREATEST},
  {"groupby_num", PT_GROUPBY_NUM},
  {"incr", PT_INCR},
  {"inst_num", PT_INST_NUM},
  {"instr", PT_INSTR},
  {"instrb", PT_INSTR},
  {"last_day", PT_LAST_DAY},
  {"length", PT_CHAR_LENGTH},
  {"lengthb", PT_CHAR_LENGTH},
  {"least", PT_LEAST},
  {"list_dbs", PT_LIST_DBS},
  {"locate", PT_LOCATE},
  {"ln", PT_LN},
  {"log2", PT_LOG2},
  {"log10", PT_LOG10},
  {"log", PT_LOG},
  {"lpad", PT_LPAD},
  {"ltrim", PT_LTRIM},
  {"mid", PT_MID},
  {"months_between", PT_MONTHS_BETWEEN},
  {"format", PT_FORMAT},
  {"now", PT_SYS_DATETIME},
  {"nvl", PT_NVL},
  {"nvl2", PT_NVL2},
  {"orderby_num", PT_ORDERBY_NUM},
  {"power", PT_POWER},
  {"pow", PT_POWER},
  {"pi", PT_PI},
  {"radians", PT_RADIANS},
  {"rand", PT_RAND},
  {"random", PT_RANDOM},
  {"reverse", PT_REVERSE},
  {"round", PT_ROUND},
  {"row_count", PT_ROW_COUNT},
  {"rpad", PT_RPAD},
  {"rtrim", PT_RTRIM},
  {"sign", PT_SIGN},
  {"sin", PT_SIN},
  {"sqrt", PT_SQRT},
  {"strcmp", PT_STRCMP},
  {"substr", PT_SUBSTRING},
  {"substrb", PT_SUBSTRING},
  {"tan", PT_TAN},
  {"time_format", PT_TIME_FORMAT},
  {"to_char", PT_TO_CHAR},
  {"to_date", PT_TO_DATE},
  {"to_datetime",PT_TO_DATETIME},
  {"to_number", PT_TO_NUMBER},
  {"to_time", PT_TO_TIME},
  {"to_timestamp", PT_TO_TIMESTAMP},
  {"trunc", PT_TRUNC},
  {"unix_timestamp", PT_UNIX_TIMESTAMP}
};


static int parser_groupby_exception = 0;




/* xxxnum_check: 0 not allowed, no compatibility check
		 1 allowed, compatibility check (search_condition)
		 2 allowed, no compatibility check (select_list) */
static int parser_instnum_check = 0;
static int parser_groupbynum_check = 0;
static int parser_orderbynum_check = 0;
static int parser_within_join_condition = 0;

/* xxx_check: 0 not allowed
              1 allowed */
static int parser_sysconnectbypath_check = 0;
static int parser_prior_check = 0;
static int parser_connectbyroot_check = 0;
static int parser_serial_check = 1;
static int parser_pseudocolumn_check = 1;
static int parser_subquery_check = 1;
static int parser_hostvar_check = 1;

/* check Oracle style outer-join operator: '(+)' */
static bool parser_found_Oracle_outer = false;

/* check sys_date, sys_time, sys_timestamp, sys_datetime local_transaction_id */
static bool parser_si_datetime = false;
static bool parser_si_tran_id = false;

/* check the condition that the statment is not able to be prepared */
static bool parser_cannot_prepare = false;

/* check the condition that the result of a query is not able to be cached */
static bool parser_cannot_cache = false;

/* check if INCR is used legally */
static int parser_select_level = -1;

/* handle inner increment exprs in select list */
static PT_NODE *parser_hidden_incr_list = NULL;

typedef struct {
	PT_NODE* c1;
	PT_NODE* c2;
} container_2;

typedef struct {
	PT_NODE* c1;
	PT_NODE* c2;
	PT_NODE* c3;
} container_3;

typedef struct {
	PT_NODE* c1;
	PT_NODE* c2;
	PT_NODE* c3;
	PT_NODE* c4;
} container_4;

typedef struct {
	PT_NODE* c1;
	PT_NODE* c2;
	PT_NODE* c3;
	PT_NODE* c4;
	PT_NODE* c5;
	PT_NODE* c6;
	PT_NODE* c7;
	PT_NODE* c8;
	PT_NODE* c9;
	PT_NODE* c10;
} container_10;

#define PT_EMPTY INT_MAX

#if defined(WINDOWS)
#define inline
#endif


#define TO_NUMBER(a)			((UINTPTR)(a))
#define FROM_NUMBER(a)			((PT_NODE*)(UINTPTR)(a))


#define SET_CONTAINER_2(a, i, j)		a.c1 = i, a.c2 = j
#define SET_CONTAINER_3(a, i, j, k)		a.c1 = i, a.c2 = j, a.c3 = k
#define SET_CONTAINER_4(a, i, j, k, l)		a.c1 = i, a.c2 = j, a.c3 = k, a.c4 = l

#define CONTAINER_AT_0(a)			(a).c1
#define CONTAINER_AT_1(a)			(a).c2
#define CONTAINER_AT_2(a)			(a).c3
#define CONTAINER_AT_3(a)			(a).c4
#define CONTAINER_AT_4(a)			(a).c5
#define CONTAINER_AT_5(a)			(a).c6
#define CONTAINER_AT_6(a)			(a).c7
#define CONTAINER_AT_7(a)			(a).c8
#define CONTAINER_AT_8(a)			(a).c9
#define CONTAINER_AT_9(a)			(a).c10

#define DOLLAR_SIGN_TEXT	"$"
#define WON_SIGN_TEXT		"\\"
#define YUAN_SIGN_TEXT		"Y"

typedef enum
{
  SERIAL_START,
  SERIAL_INC,
  SERIAL_MAX,
  SERIAL_MIN,
  SERIAL_CYCLE,
  SERIAL_CACHE,
} SERIAL_DEFINE;

void csql_yyerror_explicit(int line, int column);
void csql_yyerror(const char* s);

FUNCTION_MAP* keyword_offset(const char* name);
PT_NODE* keyword_func(const char* name, PT_NODE* args);

static PT_NODE* parser_make_expression(PT_OP_TYPE OP, PT_NODE* arg1, PT_NODE* arg2, PT_NODE* arg3);
static PT_NODE* parser_make_link(PT_NODE* list, PT_NODE* node);
static PT_NODE* parser_make_link_or(PT_NODE* list, PT_NODE* node);



static void parser_save_and_set_cannot_cache(bool value);
static void parser_restore_cannot_cache(void);

static void parser_save_and_set_si_datetime(int value);
static void parser_restore_si_datetime(void);

static void parser_save_and_set_si_tran_id(int value);
static void parser_restore_si_tran_id(void);

static void parser_save_and_set_cannot_prepare(bool value);
static void parser_restore_cannot_prepare(void);

static void parser_save_and_set_wjc(int value);
static void parser_restore_wjc(void);

static void parser_save_and_set_ic(int value);
static void parser_restore_ic(void);

static void parser_save_and_set_gc(int value);
static void parser_restore_gc(void);

static void parser_save_and_set_oc(int value);
static void parser_restore_oc(void);

static void parser_save_and_set_sysc(int value);
static void parser_restore_sysc(void);

static void parser_save_and_set_prc(int value);
static void parser_restore_prc(void);

static void parser_save_and_set_cbrc(int value);
static void parser_restore_cbrc(void);

static void parser_save_and_set_serc(int value);
static void parser_restore_serc(void);

static void parser_save_and_set_pseudoc(int value);
static void parser_restore_pseudoc(void);

static void parser_save_and_set_sqc(int value);
static void parser_restore_sqc(void);

static void parser_save_and_set_hvar(int value);
static void parser_restore_hvar(void);

static void parser_save_found_Oracle_outer(void);
static void parser_restore_found_Oracle_outer(void);

static void parser_save_alter_node(PT_NODE* node);
static PT_NODE* parser_get_alter_node(void);

static void parser_save_attr_def_one(PT_NODE* node);
static PT_NODE* parser_get_attr_def_one(void);

static void parser_push_orderby_node(PT_NODE* node);
static PT_NODE* parser_top_orderby_node(void);
static PT_NODE* parser_pop_orderby_node(void);

static void parser_push_select_stmt_node(PT_NODE* node);
static PT_NODE* parser_top_select_stmt_node(void);
static PT_NODE* parser_pop_select_stmt_node(void);


static void parser_push_hint_node(PT_NODE* node);
static PT_NODE* parser_top_hint_node(void);
static PT_NODE* parser_pop_hint_node(void);

static void parser_push_join_type(int v);
static int parser_top_join_type(void);
static int parser_pop_join_type(void);

static void parser_save_is_reverse(bool v);
static bool parser_get_is_reverse(void);

static void parser_stackpointer_init(void);
static PT_NODE* parser_make_date_lang(int arg_cnt, PT_NODE* arg3);
static void parser_remove_dummy_select(PT_NODE** node);
static int parser_count_list(PT_NODE* list);

static void resolve_alias_in_expr_node(PT_NODE * node, PT_NODE * list);
static void resolve_alias_in_name_node(PT_NODE ** node, PT_NODE * list);

static PT_MISC_TYPE parser_attr_type;

static bool allow_attribute_ordering;

int parse_one_statement (int state);


int g_msg[1024];
int msg_ptr;


#define push_msg(a) _push_msg(a, __LINE__)

void _push_msg(int code, int line);
void pop_msg(void);

%}

%locations
%glr-parser
%error_verbose


%union {
	int number;
	bool boolean;
	PT_NODE* node;
	char* cptr;
	container_2 c2;
	container_3 c3;
	container_4 c4;
	container_10 c10;
}





/* define rule type (number) */
/*{{{*/
%type <boolean> opt_reverse
%type <boolean> opt_unique
%type <number> opt_replace
%type <number> opt_of_inner_left_right
%type <number> opt_with_read_uncommitted
%type <number> opt_class_type
%type <number> opt_of_attr_column_method
%type <number> opt_class
%type <number> isolation_level_name
%type <number> opt_status
%type <number> trigger_status
%type <number> trigger_time
%type <number> opt_trigger_action_time
%type <number> event_type
%type <number> opt_of_data_type_cursor
%type <number> all_distinct
%type <number> all_distinct_distinctrow
%type <number> of_avg_max_etc
%type <number> of_leading_trailing_both
%type <number> datetime_field
%type <number> opt_paren_plus
%type <number> comp_op
%type <number> opt_of_all_some_any
%type <number> set_op
%type <number> char_bit_type
%type <number> opt_identity
%type <number> set_type
%type <number> opt_of_container
%type <number> of_container
%type <number> opt_with_levels_clause
%type <number> of_class_table_type
%type <number> opt_with_grant_option
%type <number> opt_sp_in_out
%type <number> opt_in_out
%type <number> like_op
%type <number> null_op
%type <number> is_op
%type <number> in_op
%type <number> between_op
%type <number> opt_varying
%type <number> nested_set
%type <number> opt_asc_or_desc
%type <number> opt_with_rollup
%type <number> opt_table_type
%type <number> opt_or_replace
%type <number> column_constraint_def
%type <number> constraint_list
%type <number> opt_global
/*}}}*/

/* define rule type (node) */
/*{{{*/
%type <node> stmt
%type <node> stmt_
%type <node> create_stmt
%type <node> set_stmt
%type <node> get_stmt
%type <node> auth_stmt
%type <node> transaction_stmt
%type <node> alter_stmt
%type <node> alter_clause_list
%type <node> rename_stmt
%type <node> rename_class_list
%type <node> rename_class_pair
%type <node> drop_stmt
%type <node> register_stmt
%type <node> schema_sync_stmt
%type <node> opt_index_column_name_list
%type <node> index_column_name_list
%type <node> index_column_name_list_sub
%type <node> index_column_name
%type <node> update_statistics_stmt
%type <node> only_class_name_list
%type <node> opt_level_spec
%type <node> char_string_literal_list
%type <node> table_spec_list
%type <node> join_table_spec
%type <node> table_spec
%type <node> join_condition
%type <node> class_spec_list
%type <node> class_spec
%type <node> only_all_class_spec_list
%type <node> meta_class_spec
%type <node> only_all_class_spec
%type <node> class_name
%type <node> opt_identifier
%type <node> normal_or_class_attr_list_with_commas
%type <node> normal_or_class_attr
%type <node> normal_column_or_class_attribute
%type <node> query_number_list
%type <node> insert_or_replace_stmt
%type <node> insert_set_stmt
%type <node> replace_set_stmt
%type <node> insert_set_stmt_header
%type <node> insert_expression
%type <node> opt_attr_list
%type <node> into_clause_opt
%type <node> insert_value_clause
%type <node> insert_value_clause_list
%type <node> insert_stmt_value_clause
%type <node> insert_expression_value_clause
%type <node> insert_value_list
%type <node> insert_value
%type <node> update_stmt
%type <node> of_class_spec_meta_class_spec
%type <node> opt_as_identifier
%type <node> update_assignment_list
%type <node> update_assignment
%type <node> paren_path_expression_set
%type <node> path_expression_list
%type <node> delete_stmt
%type <node> opt_class_name
%type <node> author_cmd_list
%type <node> authorized_cmd
%type <node> opt_password
%type <node> opt_groups
%type <node> opt_members
%type <node> call_stmt
%type <node> opt_class_or_normal_attr_def_list
%type <node> opt_method_def_list
%type <node> opt_method_files
%type <node> opt_inherit_resolution_list
%type <node> opt_partition_clause
%type <node> opt_paren_view_attr_def_list
%type <node> opt_as_query_list
%type <node> query_list
%type <node> inherit_resolution_list
%type <node> inherit_resolution
%type <node> opt_table_option_list
%type <node> table_option_list
%type <node> table_option
%type <node> opt_subtable_clause
%type <node> opt_constraint_id
%type <node> opt_constraint_opt_id
%type <node> of_unique_foreign_check
%type <node> unique_constraint
%type <node> foreign_key_constraint
%type <node> opt_paren_attr_list
%type <node> check_constraint
%type <node> method_def_list
%type <node> method_def
%type <node> opt_method_def_arg_list
%type <node> arg_type_list
%type <node> inout_data_type
%type <node> opt_function_identifier
%type <node> opt_class_attr_def_list
%type <node> class_or_normal_attr_def_list
%type <node> view_attr_def_list
%type <node> attr_def_list
%type <node> attr_def_list_with_commas
%type <node> attr_def
%type <node> attr_constraint_def
%type <node> attr_index_def
%type <node> attr_def_one
%type <node> view_attr_def
%type <node> transaction_mode_list
%type <node> transaction_mode
%type <node> timeout_spec
%type <node> evaluate_stmt
%type <node> prepare_stmt
%type <node> execute_stmt
%type <node> opt_using
%type <node> opt_priority
%type <node> opt_if_trigger_condition
%type <node> event_spec
%type <node> event_target
%type <node> trigger_condition
%type <node> trigger_action
%type <node> trigger_spec_list
%type <node> trace_spec
%type <node> depth_spec
%type <node> serial_start
%type <node> serial_increment
%type <node> opt_sp_param_list
%type <node> sp_param_list
%type <node> sp_param_def
%type <node> esql_query_stmt
%type <node> opt_for_update
%type <node> csql_query
%type <node> select_expression
%type <node> table_op
%type <node> select_or_subquery
%type <node> select_stmt
%type <node> opt_select_param_list
%type <node> select_list
%type <node> alias_enabled_expression_list
%type <node> alias_enabled_expression_
%type <node> expression_list
%type <node> to_param_list
%type <node> to_param
%type <node> from_param
%type <node> host_param_input
%type <node> host_param_output
%type <node> param_
%type <node> opt_where_clause
%type <node> opt_startwith_clause
%type <node> opt_connectby_clause
%type <node> opt_groupby_clause
%type <node> group_spec_list
%type <node> group_spec
%type <node> opt_having_clause
%type <node> index_name
%type <node> opt_using_index_clause
%type <node> index_name_list
%type <node> opt_with_increment_clause
%type <node> opt_orderby_clause
%type <node> sort_spec_list
%type <node> expression_
%type <node> expression_add_sub
%type <node> expression_bitshift
%type <node> expression_bitand
%type <node> expression_bitor
%type <node> term
%type <node> factor
%type <node> factor_
%type <node> primary
%type <node> boolean
%type <node> case_expr
%type <node> opt_else_expr
%type <node> simple_when_clause_list
%type <node> simple_when_clause
%type <node> searched_when_clause_list
%type <node> searched_when_clause
%type <node> extract_expr
%type <node> opt_expression_list
%type <node> table_set_function_call
%type <node> search_condition
%type <node> boolean_term
%type <node> boolean_term_is
%type <node> boolean_term_xor
%type <node> boolean_factor
%type <node> predicate
%type <node> predicate_expression
%type <node> predicate_expr_sub
%type <node> range_list
%type <node> range_
%type <node> subquery
%type <node> path_expression
%type <node> data_type_list
%type <node> opt_prec_1
%type <node> signed_literal_
%type <node> literal_
%type <node> literal_w_o_param
%type <node> constant_set
%type <node> file_path_name
%type <node> identifier_list
%type <node> index_column_identifier_list
%type <node> identifier
%type <node> index_column_identifier
%type <node> escape_string_literal
%type <node> char_string_literal
%type <node> char_string
%type <node> bit_string_literal
%type <node> bit_string
%type <node> unsigned_integer
%type <node> unsigned_int32
%type <node> unsigned_real
%type <node> monetary_literal
%type <node> date_or_time_literal
%type <node> partition_clause
%type <node> partition_def_list
%type <node> partition_def
%type <node> signed_literal_list
%type <node> insert_name_clause
%type <node> replace_name_clause
%type <node> insert_name_clause_header
%type <node> opt_for_search_condition
%type <node> path_header
%type <node> path_id_list
%type <node> path_id
%type <node> simple_path_id
%type <node> generic_function
%type <node> opt_on_target
%type <node> generic_function_id
%type <node> pred_lhs
%type <node> pseudo_column
%type <node> reserved_func
%type <node> sort_spec
%type <node> trigger_priority
%type <node> class_or_normal_attr_def
%type <node> on_class_list
%type <node> from_id_list
%type <node> to_id_list
%type <node> only_class_name
%type <node> grant_head
%type <node> grant_cmd
%type <node> revoke_cmd
%type <node> opt_from_table_spec_list
%type <node> method_file_list
%type <node> incr_arg_name_list__inc
%type <node> incr_arg_name__inc
%type <node> incr_arg_name_list__dec
%type <node> incr_arg_name__dec
%type <node> search_condition_query
%type <node> search_condition_expression
%type <node> opt_uint_or_host_input
%type <node> opt_upd_del_limit_clause
%type <node> truncate_stmt
%type <node> do_stmt
%type <node> on_duplicate_key_update
%type <node> opt_attr_ordering_info
%type <node> opt_on_node
%type <node> opt_port
/*}}}*/

/* define rule type (cptr) */
/*{{{*/
%type <cptr> uint_text
%type <cptr> of_integer_real_literal
%type <cptr> integer_text
/*}}}*/

/* define rule type (container) */
/*{{{*/
%type <c10> opt_serial_option_list
%type <c10> serial_option_list

%type <c4> isolation_level_spec
%type <c4> opt_constraint_attr_list
%type <c4> constraint_attr_list
%type <c4> constraint_attr

%type <c3> ref_rule_list
%type <c3> opt_ref_rule_list
%type <c3> of_serial_option

%type <c2> extended_table_spec_list
%type <c2> alter_attr_default_value_list
%type <c2> opt_of_where_cursor
%type <c2> opt_data_type
%type <c2> opt_create_as_clause
%type <c2> create_as_clause
%type <c2> trigger_status_or_priority
%type <c2> serial_min
%type <c2> serial_max
%type <c2> of_cached_num
%type <c2> of_cycle_nocycle
%type <c2> data_type
%type <c2> primitive_type
%type <c2> opt_prec_2
%type <c2> in_pred_operand
%type <c2> opt_as_identifier_attr_name
%type <c2> insert_assignment_list
/*}}}*/

/* Token define */
/*{{{*/
%token ABSOLUTE_
%token ACTION
%token ADD
%token ADD_MONTHS
%token AFTER
%token ALIAS
%token ALL
%token ALLOCATE
%token ALTER
%token AND
%token ANY
%token ARE
%token AS
%token ASC
%token ASSERTION
%token ASYNC
%token AT
%token ATTACH
%token ATTRIBUTE
%token AVG
%token BEFORE
%token BEGIN_
%token BETWEEN
%token BIGINT
%token BIT
%token BIT_LENGTH
%token BITSHIFT_LEFT
%token BITSHIFT_RIGHT
%token BOOLEAN_
%token BOTH_
%token BREADTH
%token BY
%token CALL
%token CASCADE
%token CASCADED
%token CASE
%token CAST
%token CATALOG
%token CHANGE
%token CHAR_
%token CHECK
%token CLASS
%token CLASSES
%token CLOSE
%token CLUSTER
%token COALESCE
%token COLLATE
%token COLLATION
%token COLUMN
%token COMMIT
%token COMP_NULLSAFE_EQ
%token COMPLETION
%token CONNECT
%token CONNECT_BY_ISCYCLE
%token CONNECT_BY_ISLEAF
%token CONNECT_BY_ROOT
%token CONNECTION
%token CONSTRAINT
%token CONSTRAINTS
%token CONTINUE
%token CONVERT
%token CORRESPONDING
%token COUNT
%token CREATE
%token CROSS
%token CURRENT
%token CURRENT_DATE
%token CURRENT_DATETIME
%token CURRENT_TIME
%token CURRENT_TIMESTAMP
%token CURRENT_USER
%token CURSOR
%token CYCLE
%token DATA
%token DATABASE
%token DATA_TYPE
%token Date
%token DATETIME
%token DAY_
%token DAY_MILLISECOND
%token DAY_SECOND
%token DAY_MINUTE
%token DAY_HOUR
%token DEALLOCATE
%token DECLARE
%token DEFAULT
%token DEFERRABLE
%token DEFERRED
%token DELETE_
%token DEPTH
%token DESC
%token DESCRIBE
%token DESCRIPTOR
%token DIAGNOSTICS
%token DICTIONARY
%token DIFFERENCE_
%token DISCONNECT
%token DISTINCT
%token DISTINCTROW
%token DIV
%token DO
%token Domain
%token Double
%token DROP
%token DUPLICATE_
%token EACH
%token ELSE
%token ELSEIF
%token END
%token EQUALS
%token ESCAPE
%token EVALUATE
%token EXCEPT
%token EXCEPTION
%token EXCLUDE
%token EXEC
%token EXECUTE
%token EXISTS
%token EXTERNAL
%token EXTRACT
%token False
%token FETCH
%token File
%token FIRST
%token FLOAT_
%token For
%token FOREIGN
%token FOUND
%token FROM
%token FULL
%token FUNCTION
%token GENERAL
%token GET
%token GLOBAL
%token GO
%token GOTO
%token GRANT
%token GROUP_
%token HAVING
%token HOUR_
%token HOUR_MILLISECOND
%token HOUR_SECOND
%token HOUR_MINUTE
%token IDENTITY
%token IF
%token IGNORE_
%token IMMEDIATE
%token IN_
%token INDEX
%token INDICATOR
%token INHERIT
%token INITIALLY
%token INNER
%token INOUT
%token INPUT_
%token INSERT
%token INTEGER
%token INTERSECT
%token INTERSECTION
%token INTERVAL
%token INTO
%token IS
%token ISOLATION
%token JOIN
%token KEY
%token LANGUAGE
%token LAST
%token LDB
%token LEADING_
%token LEAVE
%token LEFT
%token LESS
%token LEVEL
%token LIKE
%token LIMIT
%token LIST
%token LOCAL
%token LOCAL_TRANSACTION_ID
%token LOCALTIME
%token LOCALTIMESTAMP
%token LOOP
%token LOWER
%token MATCH
%token Max
%token METHOD
%token MILLISECOND_
%token Min
%token MINUTE_
%token MINUTE_MILLISECOND
%token MINUTE_SECOND
%token MOD
%token MODIFY
%token MODULE
%token Monetary
%token MONTH_
%token MULTISET
%token MULTISET_OF
%token NA
%token NAMES
%token NATIONAL
%token NATURAL
%token NCHAR
%token NEXT
%token NO
%token NONE
%token NOT
%token Null
%token NULLIF
%token NUMERIC
%token OBJECT
%token OCTET_LENGTH
%token OF
%token OFF_
%token OID_
%token ON_
%token ONLY
%token OPEN
%token OPERATION
%token OPERATORS
%token OPTIMIZATION
%token OPTION
%token OR
%token ORDER
%token OTHERS
%token OUT_
%token OUTER
%token OUTPUT
%token OVERLAPS
%token PARAMETERS
%token PARTIAL
%token PENDANT
%token POSITION
%token PRECISION
%token PREORDER
%token PREPARE
%token PRESERVE
%token PRIMARY
%token PRIOR
%token Private
%token PRIVILEGES
%token PROCEDURE
%token PROTECTED
%token PROXY
%token QUERY
%token READ
%token REBUILD
%token RECURSIVE
%token REF
%token REFERENCES
%token REFERENCING
%token RELATIVE_
%token RENAME
%token REPLACE
%token RESIGNAL
%token RESTRICT
%token RETURN
%token RETURNS
%token REVOKE
%token RIGHT
%token ROLE
%token ROLLBACK
%token ROLLUP
%token ROUTINE
%token ROW
%token ROWNUM
%token ROWS
%token SAVEPOINT
%token SCHEMA
%token SCOPE
%token SCROLL
%token SEARCH
%token SECOND_
%token SECOND_MILLISECOND
%token SECTION
%token SELECT
%token SENSITIVE
%token SEQUENCE
%token SEQUENCE_OF
%token SERIALIZABLE
%token SESSION
%token SESSION_USER
%token SET
%token SET_OF
%token SETEQ
%token SETNEQ
%token SHARED
%token SIBLINGS
%token SIGNAL
%token SIMILAR
%token SIZE_
%token SmallInt
%token SOME
%token SQL
%token SQLCODE
%token SQLERROR
%token SQLEXCEPTION
%token SQLSTATE
%token SQLWARNING
%token STATISTICS
%token String
%token STRUCTURE
%token SUBCLASS
%token SUBSET
%token SUBSETEQ
%token SUBSTRING_
%token SUM
%token SUPERCLASS
%token SUPERSET
%token SUPERSETEQ
%token SYS_CONNECT_BY_PATH
%token SYS_DATE
%token SYS_DATETIME
%token SYS_TIME_
%token SYS_TIMESTAMP
%token SYS_USER
%token SYSTEM_USER
%token TABLE
%token TEMPORARY
%token TEST
%token THEN
%token THERE
%token Time
%token TIMESTAMP
%token TIMEZONE_HOUR
%token TIMEZONE_MINUTE
%token TO
%token TRAILING_
%token TRANSACTION
%token TRANSLATE
%token TRANSLATION
%token TRIGGER
%token TRIM
%token True
%token TRUNCATE
%token TYPE
%token UNDER
%token Union
%token UNIQUE
%token UNKNOWN
%token UNTERMINATED_STRING
%token UNTERMINATED_IDENTIFIER
%token UPDATE
%token UPPER
%token USAGE
%token USE
%token USER
%token USING
%token Utime
%token VALUE
%token VALUES
%token VARCHAR
%token VARIABLE_
%token VARYING
%token VCLASS
%token VIEW
%token VIRTUAL
%token VISIBLE
%token WAIT
%token WHEN
%token WHENEVER
%token WHERE
%token WHILE
%token WITH
%token WITHOUT
%token WORK
%token WRITE
%token XOR
%token YEAR_
%token YEAR_MONTH
%token ZONE

%token DOLLAR_SIGN
%token WON_SIGN
%token YUAN_SIGN

%token RIGHT_ARROW
%token STRCAT
%token COMP_NOT_EQ
%token COMP_GE
%token COMP_LE
%token PARAM_HEADER

%token <cptr> ACTIVE
%token <cptr> ADDDATE
%token <cptr> ANALYZE
%token <cptr> AUTO_INCREMENT
%token <cptr> BIT_AND
%token <cptr> BIT_OR
%token <cptr> BIT_XOR
%token <cptr> CACHE
%token <cptr> COMMITTED
%token <cptr> COST
%token <cptr> DATE_ADD
%token <cptr> DATE_SUB
%token <cptr> DECREMENT
%token <cptr> GE_INF_
%token <cptr> GE_LE_
%token <cptr> GE_LT_
%token <cptr> GROUPS
%token <cptr> GT_INF_
%token <cptr> GT_LE_
%token <cptr> GT_LT_
%token <cptr> HASH
%token <cptr> IFNULL
%token <cptr> INACTIVE
%token <cptr> INCREMENT
%token <cptr> INF_LE_
%token <cptr> INF_LT_
%token <cptr> INFINITE_
%token <cptr> INSTANCES
%token <cptr> INVALIDATE
%token <cptr> ISNULL
%token <cptr> JAVA
%token <cptr> LCASE
%token <cptr> LOCK_
%token <cptr> MAXIMUM
%token <cptr> MAXVALUE
%token <cptr> MEMBERS
%token <cptr> MINVALUE
%token <cptr> NAME
%token <cptr> NOCYCLE
%token <cptr> NOCACHE
%token <cptr> NODE
%token <cptr> NOMAXVALUE
%token <cptr> NOMINVALUE
%token <cptr> PARTITION
%token <cptr> PARTITIONING
%token <cptr> PARTITIONS
%token <cptr> PASSWORD
%token <cptr> PRINT
%token <cptr> PRIORITY
%token <cptr> QUARTER
%token <cptr> RANGE_
%token <cptr> REJECT_
%token <cptr> REMOVE
%token <cptr> REGISTER
%token <cptr> REORGANIZE
%token <cptr> REPEATABLE
%token <cptr> RETAIN
%token <cptr> REUSE_OID
%token <cptr> REVERSE
%token <cptr> SCHEMA_SYNC
%token <cptr> SERIAL
%token <cptr> STABILITY
%token <cptr> START_
%token <cptr> STATEMENT
%token <cptr> STATUS
%token <cptr> STDDEV
%token <cptr> STR_TO_DATE
%token <cptr> SUBDATE
%token <cptr> SYSTEM
%token <cptr> THAN
%token <cptr> TIMEOUT
%token <cptr> TRACE
%token <cptr> TRIGGERS
%token <cptr> UCASE
%token <cptr> UNCOMMITTED
%token <cptr> UNREGISTER
%token <cptr> VARIANCE
%token <cptr> WEEK
%token <cptr> WORKSPACE


%token <cptr> IdName
%token <cptr> BracketDelimitedIdName
%token <cptr> BacktickDelimitedIdName
%token <cptr> DelimitedIdName
%token <cptr> UNSIGNED_INTEGER
%token <cptr> UNSIGNED_REAL
%token <cptr> CHAR_STRING
%token <cptr> NCHAR_STRING
%token <cptr> BIT_STRING
%token <cptr> HEX_STRING
%token <cptr> CPP_STYLE_HINT
%token <cptr> C_STYLE_HINT
%token <cptr> SQL_STYLE_HINT

/*}}}*/

%%

stmt_done
	: stmt_list
	| /* empty */
	;

stmt_list
	: stmt_list stmt
		{{

			if ($2 != NULL)
			  {
			    if (parser_statement_OK)
			      this_parser->statement_number++;
			    else
			      parser_statement_OK = 1;

			    pt_push (this_parser, $2);

			#ifdef PARSER_DEBUG
			    printf ("node: %s\n", parser_print_tree (this_parser, $2));
			#endif
			  }

		DBG_PRINT}}
	| stmt
		{{

			if ($1 != NULL)
			  {
			    if (parser_statement_OK)
			      {
				this_parser->statement_number++;
			      }
			    else
			      parser_statement_OK = 1;

			    pt_push (this_parser, $1);

			#ifdef PARSER_DEBUG
			    printf ("node: %s\n", parser_print_tree (this_parser, $1));
			#endif
			  }

		DBG_PRINT}}
	;



stmt
	:
		{{

			msg_ptr = 0;

		DBG_PRINT}}
		{{

			parser_stackpointer_init ();

			parser_statement_OK = 1;
			parser_instnum_check = 0;
			parser_groupbynum_check = 0;
			parser_orderbynum_check = 0;

			parser_sysconnectbypath_check = 0;
			parser_prior_check = 0;
			parser_connectbyroot_check = 0;
			parser_serial_check = 1;
			parser_subquery_check = 1;
			parser_pseudocolumn_check = 1;
			parser_hostvar_check = 1;

			parser_select_level = -1;

			parser_within_join_condition = 0;
			parser_found_Oracle_outer = false;

			parser_save_and_set_si_datetime (false);
			parser_save_and_set_si_tran_id (false);
			parser_save_and_set_cannot_prepare (false);

			parser_attr_type = PT_NORMAL;
			allow_attribute_ordering = false;
			parser_hidden_incr_list = NULL;

		DBG_PRINT}}
	stmt_
		{{

			#ifdef PARSER_DEBUG
			if (msg_ptr == 0)
			  printf ("Good!!!\n");
			#endif

			if (msg_ptr > 0)
			  {
			    csql_yyerror (NULL);
			  }

		DBG_PRINT}}
		{{

			PT_NODE *node = $3;

			if (node)
			  {
			    node->si_datetime = (parser_si_datetime == true) ? 1 : 0;
			    node->si_tran_id = (parser_si_tran_id == true) ? 1 : 0;
			    node->cannot_prepare = (parser_cannot_prepare == true) ? 1 : 0;
			  }

			parser_restore_si_datetime ();
			parser_restore_si_tran_id ();
			parser_restore_cannot_prepare ();

			$$ = node;

		DBG_PRINT}}
	| ';'
		{{

			$$ = NULL;

		DBG_PRINT}}
	;
stmt_
	: create_stmt
		{ $$ = $1; }
	| alter_stmt
		{ $$ = $1; }
	| rename_stmt
		{ $$ = $1; }
	| update_statistics_stmt
		{ $$ = $1; }
	| drop_stmt
		{ $$ = $1; }
	| do_stmt
		{ $$ = $1; }
	| esql_query_stmt
		{ $$ = $1; }
	| evaluate_stmt
		{ $$ = $1; }
	| prepare_stmt
		{ $$ = $1; }
	| execute_stmt
		{ $$ = $1; }
	| insert_or_replace_stmt
		{ $$ = $1; }
	| update_stmt
		{ $$ = $1; }
	| delete_stmt
		{ $$ = $1; }
	| call_stmt
		{ $$ = $1; }
	| auth_stmt
		{ $$ = $1; }
	| transaction_stmt
		{ $$ = $1; }
	| truncate_stmt
		{ $$ = $1; }
	| set_stmt
		{ $$ = $1; }
	| get_stmt
		{ $$ = $1; }
	| register_stmt
		{ $$ = $1; }
	| schema_sync_stmt
		{ $$ = $1; }
	| DATA_TYPE data_type
		{{

			PT_NODE *dt, *set_dt;
			PT_TYPE_ENUM typ;

			typ = TO_NUMBER (CONTAINER_AT_0 ($2));
			dt = CONTAINER_AT_1 ($2);

			if (!dt)
			  {
			    dt = parser_new_node (this_parser, PT_DATA_TYPE);
			    if (dt)
			      {
				dt->type_enum = typ;
				dt->data_type = NULL;
			      }
			  }
			else
			  {
			    if ((typ == PT_TYPE_SET) ||
				(typ == PT_TYPE_MULTISET) || (typ == PT_TYPE_SEQUENCE))
			      {
				set_dt = parser_new_node (this_parser, PT_DATA_TYPE);
				if (set_dt)
				  {
				    set_dt->type_enum = typ;
				    set_dt->data_type = dt;
				    dt = set_dt;
				  }
			      }
			  }

			$$ = dt;

		DBG_PRINT}}
	| ATTACH
		{ push_msg(MSGCAT_SYNTAX_INVALID_ATTACH); }
	  unsigned_integer
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_ATTACH);

			if (node)
			  {
			    node->info.attach.trans_id = $3->info.value.data_value.i;
			  }

			$$ = node;

		DBG_PRINT}}
	| PREPARE
		{ push_msg(MSGCAT_SYNTAX_INVALID_PREPARE); }
	  opt_to COMMIT unsigned_integer
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_PREPARE_TO_COMMIT);

			if (node)
			  {
			    node->info.prepare_to_commit.trans_id = $5->info.value.data_value.i;
			  }

			$$ = node;

		DBG_PRINT}}
	| EXECUTE
		{ push_msg(MSGCAT_SYNTAX_INVALID_EXECUTE); }
	  DEFERRED TRIGGER trigger_spec_list
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_EXECUTE_TRIGGER);

			if (node)
			  {
			    node->info.execute_trigger.trigger_spec_list = $5;
			  }

			$$ = node;

		DBG_PRINT}}
	| SCOPE
		{ push_msg(MSGCAT_SYNTAX_INVALID_SCOPE); }
	  trigger_action opt_from_table_spec_list
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SCOPE);

			if (node)
			  {
			    node->info.scope.stmt = $3;
			    node->info.scope.from = $4;
			  }

			$$ = node;

		DBG_PRINT}}
	;


opt_from_table_spec_list
	: /* empty */
		{ $$ = NULL; }
	| FROM table_spec_list
		{ $$ = $2; }
	;


set_stmt
	: SET OPTIMIZATION
		{ push_msg(MSGCAT_SYNTAX_INVALID_SET_OPT_LEVEL); }
	  LEVEL opt_of_to_eq opt_level_spec
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SET_OPT_LVL);
			if (node)
			  {
			    node->info.set_opt_lvl.option = PT_OPT_LVL;
			    node->info.set_opt_lvl.val = $6;
			  }

			$$ = node;

		DBG_PRINT}}
	| SET OPTIMIZATION
		{ push_msg(MSGCAT_SYNTAX_INVALID_SET_OPT_COST); }
	  COST opt_of char_string_literal opt_of_to_eq literal_
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SET_OPT_LVL);
			if (node)
			  {
			    node->info.set_opt_lvl.option = PT_OPT_COST;
			    if ($6)
			      ($6)->next = $8;
			    node->info.set_opt_lvl.val = $6;
			  }

			$$ = node;

		DBG_PRINT}}
	| SET
		{ push_msg(MSGCAT_SYNTAX_INVALID_SET_SYS_PARAM); }
	  SYSTEM PARAMETERS char_string_literal_list
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SET_SYS_PARAMS);
			if (node)
			  node->info.set_sys_params.val = $5;
			$$ = node;

		DBG_PRINT}}
	| SET
		{ push_msg(MSGCAT_SYNTAX_INVALID_SET_TRAN); }
	  TRANSACTION transaction_mode_list
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SET_XACTION);

			if (node)
			  {
			    node->info.set_xaction.xaction_modes = $4;
			  }

			$$ = node;

		DBG_PRINT}}
	| SET TRIGGER
		{ push_msg(MSGCAT_SYNTAX_INVALID_SET_TRIGGER_TRACE); }
	  TRACE trace_spec
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SET_TRIGGER);

			if (node)
			  {
			    node->info.set_trigger.option = PT_TRIGGER_TRACE;
			    node->info.set_trigger.val = $5;
			  }

			$$ = node;

		DBG_PRINT}}
	| SET TRIGGER
		{ push_msg(MSGCAT_SYNTAX_INVALID_SET_TRIGGER_DEPTH); }
	  opt_maximum DEPTH depth_spec
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SET_TRIGGER);

			if (node)
			  {
			    node->info.set_trigger.option = PT_TRIGGER_DEPTH;
			    node->info.set_trigger.val = $6;
			  }

			$$ = node;

		DBG_PRINT}}
	;




get_stmt
	: GET
		{ push_msg(MSGCAT_SYNTAX_INVALID_GET_STAT); }
	  STATISTICS char_string_literal  OF class_name into_clause_opt
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_GET_STATS);
			if (node)
			  {
			    node->info.get_stats.into_var = $7;
			    node->info.get_stats.class_ = $6;
			    node->info.get_stats.args = $4;
			  }
			$$ = node;

		DBG_PRINT}}
	| GET OPTIMIZATION
		{ push_msg(MSGCAT_SYNTAX_INVALID_GET_OPT_LEVEL); }
	  LEVEL into_clause_opt
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_GET_OPT_LVL);
			if (node)
			  {
			    node->info.get_opt_lvl.into_var = $5;
			    node->info.get_opt_lvl.option = PT_OPT_LVL;
			    node->info.get_opt_lvl.args = NULL;
			  }
			$$ = node;

		DBG_PRINT}}
	| GET OPTIMIZATION
		{ push_msg(MSGCAT_SYNTAX_INVALID_GET_OPT_COST); }
	  COST opt_of char_string_literal into_clause_opt
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_GET_OPT_LVL);
			if (node)
			  {
			    node->info.get_opt_lvl.into_var = $7;
			    node->info.get_opt_lvl.option = PT_OPT_COST;
			    node->info.get_opt_lvl.args = $6;
			  }
			$$ = node;

		DBG_PRINT}}
	| GET TRANSACTION
		{ push_msg(MSGCAT_SYNTAX_INVALID_GET_TRAN_ISOL); }
	  ISOLATION LEVEL into_clause_opt
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_GET_XACTION);

			if (node)
			  {
			    node->info.get_xaction.into_var = $6;
			    node->info.get_xaction.option = PT_ISOLATION_LEVEL;
			  }

			$$ = node;

		DBG_PRINT}}
	| GET TRANSACTION
		{ push_msg(MSGCAT_SYNTAX_INVALID_GET_TRAN_LOCK); }
	  LOCK_ TIMEOUT into_clause_opt
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_GET_XACTION);

			if (node)
			  {
			    node->info.get_xaction.into_var = $6;
			    node->info.get_xaction.option = PT_LOCK_TIMEOUT;
			  }

			$$ = node;

		DBG_PRINT}}
	| GET TRIGGER
		{ push_msg(MSGCAT_SYNTAX_INVALID_GET_TRIGGER_TRACE); }
	  TRACE into_clause_opt
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_GET_TRIGGER);

			if (node)
			  {
			    node->info.get_trigger.into_var = $5;
			    node->info.get_trigger.option = PT_TRIGGER_TRACE;
			  }

			$$ = node;

		DBG_PRINT}}
	| GET TRIGGER
		{ push_msg(MSGCAT_SYNTAX_INVALID_GET_TRIGGER_DEPTH); }
	  opt_maximum DEPTH into_clause_opt
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_GET_TRIGGER);

			if (node)
			  {
			    node->info.get_trigger.into_var = $6;
			    node->info.get_trigger.option = PT_TRIGGER_DEPTH;
			  }

			$$ = node;

		DBG_PRINT}}
	;




create_stmt
	: CREATE					/* 1 */
		{					/* 2 */
			PT_NODE* qc = parser_new_node(this_parser, PT_CREATE_ENTITY);
			parser_push_hint_node(qc);
		}
	  opt_hint_list					/* 3 */
	  opt_global					/* 4 */
	  of_class_table_type				/* 5 */
	  class_name					/* 6 */
	  opt_subtable_clause 				/* 7 */
	  opt_class_attr_def_list			/* 8 */
	  opt_class_or_normal_attr_def_list		/* 9 */
	  opt_table_option_list				/* 10 */
	  opt_method_def_list 				/* 11 */
	  opt_method_files 				/* 12 */
	  opt_inherit_resolution_list			/* 13 */
	  opt_partition_clause 				/* 14 */
          opt_create_as_clause				/* 15 */
	  opt_on_node					/* 16 */
		{{

			PT_NODE *qc = parser_pop_hint_node ();

			if($4 == 0 && $16 != NULL)
			  {
			    PT_ERRORm (this_parser, qc, MSGCAT_SET_PARSER_SYNTAX,
					MSGCAT_SYNTAX_MISSING_GLOABL_KEYWORD);
			  }

			if (CONTAINER_AT_1 ($15) != NULL)
			  {
			    if ((PT_MISC_TYPE) $5 == PT_ADT || $7 != NULL || $8 != NULL || $11 != NULL
				|| $12 != NULL || $13 != NULL)
			      {
				PT_ERRORf (this_parser, qc, "check syntax at %s",
                                          parser_print_tree (this_parser, qc));
			      }
			  }

			if (qc)
			  {
			    qc->info.create_entity.entity_name = $6;
			    qc->info.create_entity.entity_type = (PT_MISC_TYPE) $5;
			    qc->info.create_entity.supclass_list = $7;
			    qc->info.create_entity.class_attr_def_list = $8;
			    qc->info.create_entity.attr_def_list = $9;
			    qc->info.create_entity.table_option_list = $10;
			    qc->info.create_entity.method_def_list = $11;
			    qc->info.create_entity.method_file_list = $12;
			    qc->info.create_entity.resolution_list = $13;
			    qc->info.create_entity.partition_info = $14;
                            if (CONTAINER_AT_1 ($15) != NULL)
			      {
			        qc->info.create_entity.create_select_action = TO_NUMBER(CONTAINER_AT_0 ($15));
			        qc->info.create_entity.create_select = CONTAINER_AT_1 ($15);
			      }

			    qc->info.create_entity.global_entity = (PT_MISC_TYPE) $4;
			    qc->info.create_entity.on_node = $16;

			    pt_gather_constraints (this_parser, qc);
			  }

			$$ = qc;

		DBG_PRINT}}
	| CREATE 					/* 1 */
	  opt_or_replace				/* 2 */
	  opt_global					/* 3 */
	  of_view_vclass 				/* 4 */
	  class_name 					/* 5 */
	  opt_subtable_clause 				/* 6 */
	  opt_class_attr_def_list 			/* 7 */
	  opt_paren_view_attr_def_list 			/* 8 */
	  opt_method_def_list 				/* 9 */
	  opt_method_files				/* 10 */
	  opt_inherit_resolution_list			/* 11 */
	  opt_as_query_list				/* 12 */
	  opt_with_levels_clause			/* 13 */
		{{

			PT_NODE *qc = parser_new_node (this_parser, PT_CREATE_ENTITY);

			if (qc)
			  {
			    qc->info.create_entity.or_replace = $2;

			    qc->info.create_entity.entity_name = $5;
			    qc->info.create_entity.entity_type = PT_VCLASS;

			    qc->info.create_entity.supclass_list = $6;
			    qc->info.create_entity.class_attr_def_list = $7;
			    qc->info.create_entity.attr_def_list = $8;
			    qc->info.create_entity.method_def_list = $9;
			    qc->info.create_entity.method_file_list = $10;
			    qc->info.create_entity.resolution_list = $11;
			    qc->info.create_entity.as_query_list = $12;
			    qc->info.create_entity.with_check_option = $13;

			    qc->info.create_entity.global_entity = (PT_MISC_TYPE) $3;

			    pt_gather_constraints (this_parser, qc);
			  }


			$$ = qc;

		DBG_PRINT}}
	| CREATE					/* 1 */
		{					/* 2 */
			PT_NODE* node = parser_new_node (this_parser, PT_CREATE_INDEX);
			parser_push_hint_node (node);
			push_msg (MSGCAT_SYNTAX_INVALID_CREATE_INDEX);
		}
	  opt_hint_list					/* 3 */
	  opt_global					/* 4 */
	  opt_reverse					/* 5 */
	  opt_unique					/* 6 */
	  INDEX						/* 7 */
	  opt_identifier				/* 8 */
	  ON_						/* 9 */
	  only_class_name				/* 10 */
	  index_column_name_list			/* 11 */
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_pop_hint_node ();

			node->info.index.reverse = $5;
			node->info.index.unique = $6;

			node->info.index.index_name = $8;
			node->info.index.indexed_class = $10;
			node->info.index.column_names = $11;

			node->info.index.global_entity = (PT_MISC_TYPE) $4;

			$$ = node;

		DBG_PRINT}}
	| CREATE					/* 1 */
		{					/* 2 */
			PT_NODE* node = parser_new_node (this_parser, PT_CREATE_INDEX);
			parser_push_hint_node (node);
			push_msg (MSGCAT_SYNTAX_INVALID_CREATE_INDEX);
		}
	  opt_hint_list					/* 3 */
  	  opt_global					/* 4 */
	  INDEX						/* 5 */
	  opt_identifier				/* 6 */
	  ON_						/* 7 */
	  only_class_name				/* 8 */
	  '(' index_column_name				/* 9, 10 */
	  '(' opt_uint_or_host_input ')' 		/* 11, 12, 13 */
	  opt_asc_or_desc ')'				/* 14, 15 */
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_pop_hint_node ();

			node->info.index.index_name = $6;
			node->info.index.indexed_class = $8;
			node->info.index.column_names = $10;
			node->info.index.prefix_length = $12;

			if ($10 && $14)
			  {
			    $10->info.sort_spec.asc_or_desc = $14;
			  }

			node->info.index.global_entity = (PT_MISC_TYPE) $4;

			$$ = node;

		DBG_PRINT}}
	| CREATE					/* 1 */
		{					/* 2 */
			push_msg(MSGCAT_SYNTAX_INVALID_CREATE_USER);
		}
	  opt_global					/* 3 */
	  USER						/* 4 */
	  identifier					/* 5 */
	  opt_password					/* 6 */
	  opt_groups					/* 7 */
	  opt_members					/* 8 */
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_CREATE_USER);

			if (node)
			  {
			    node->info.create_user.user_name = $5;
			    node->info.create_user.password = $6;
			    node->info.create_user.groups = $7;
			    node->info.create_user.members = $8;

			    node->info.create_user.global_entity = (PT_MISC_TYPE) $3;
			  }

			$$ = node;

		DBG_PRINT}}
	| CREATE 					/* 1 */
		{ push_msg(MSGCAT_SYNTAX_INVALID_CREATE_TRIGGER); }	/* 2 */
	  TRIGGER 					/* 3 */
	  identifier 					/* 4 */
	  opt_status					/* 5 */
	  opt_priority					/* 6 */
	  trigger_time 					/* 7 */
		{ pop_msg(); }				/* 8 */
	  event_spec 					/* 9 */
	  opt_if_trigger_condition			/* 10 */
	  EXECUTE					/* 11 */
	  opt_trigger_action_time 			/* 12 */
	  trigger_action				/* 13 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_CREATE_TRIGGER);

			if (node)
			  {
			    node->info.create_trigger.trigger_name = $4;
			    node->info.create_trigger.trigger_status = $5;
			    node->info.create_trigger.trigger_priority = $6;
			    node->info.create_trigger.condition_time = $7;
			    node->info.create_trigger.trigger_event = $9;
			    node->info.create_trigger.trigger_reference = NULL;
			    node->info.create_trigger.trigger_condition = $10;
			    node->info.create_trigger.action_time = $12;
			    node->info.create_trigger.trigger_action = $13;
			  }

			$$ = node;

		DBG_PRINT}}
	| CREATE					/* 1 */
		{ push_msg(MSGCAT_SYNTAX_INVALID_CREATE_SERIAL); }	/* 2 */
	  opt_global					/* 3 */
	  SERIAL 					/* 4 */
	  identifier 					/* 5 */
	  opt_serial_option_list			/* 6 */
	  opt_on_node					/* 7 */
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_CREATE_SERIAL);

			if($3 == 0 && $7 != NULL)
			  {
			    PT_ERRORm (this_parser, node, MSGCAT_SET_PARSER_SYNTAX,
					MSGCAT_SYNTAX_MISSING_GLOABL_KEYWORD);
			  }

			if (node)
			  {
			    node->info.serial.serial_name = $5;

			    /* container order
			     * 0: start_val
			     * 1: increment_val,
			     * 2: max_val,
			     * 3: no_max,
			     * 4: min_val,
			     * 5: no_min,
			     * 6: cyclic,
			     * 7: no_cyclic,
			     * 8: cached_num_val,
			     * 9: no_cache,
			     */

			    node->info.serial.start_val = CONTAINER_AT_0($6);
			    node->info.serial.increment_val = CONTAINER_AT_1($6);
			    node->info.serial.max_val = CONTAINER_AT_2 ($6);
			    node->info.serial.no_max = TO_NUMBER (CONTAINER_AT_3 ($6));
			    node->info.serial.min_val = CONTAINER_AT_4 ($6);
			    node->info.serial.no_min = TO_NUMBER (CONTAINER_AT_5 ($6));
			    node->info.serial.cyclic = TO_NUMBER (CONTAINER_AT_6 ($6));
			    node->info.serial.no_cyclic = TO_NUMBER (CONTAINER_AT_7 ($6));
			    node->info.serial.cached_num_val = CONTAINER_AT_8 ($6);
			    node->info.serial.no_cache = TO_NUMBER (CONTAINER_AT_9 ($6));

			    node->info.serial.global_entity = (PT_MISC_TYPE) $3;
			    node->info.serial.on_node = $7;
			  }

			$$ = node;

		DBG_PRINT}}
	| CREATE						/* 1 */
		{ push_msg(MSGCAT_SYNTAX_INVALID_CREATE_PROCEDURE); }		/* 2 */
	  PROCEDURE						/* 3 */
	  identifier '(' opt_sp_param_list  ')'			/* 4, 5, 6, 7 */
	  opt_of_is_as LANGUAGE JAVA				/* 8, 9, 10 */
	  NAME char_string_literal				/* 11, 12 */
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_CREATE_STORED_PROCEDURE);
			if (node)
			  {
			    node->info.sp.name = $4;
			    node->info.sp.type = PT_SP_PROCEDURE;
			    node->info.sp.param_list = $6;
			    node->info.sp.ret_type = PT_TYPE_NONE;
			    node->info.sp.java_method = $12;
			  }

			$$ = node;

		DBG_PRINT}}
	| CREATE
		{ push_msg(MSGCAT_SYNTAX_INVALID_CREATE_FUNCTION); }
	  FUNCTION
	  identifier '('  opt_sp_param_list  ')'
	  RETURN opt_of_data_type_cursor
	  opt_of_is_as LANGUAGE JAVA
	  NAME char_string_literal
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_CREATE_STORED_PROCEDURE);
			if (node)
			  {
			    node->info.sp.name = $4;
			    node->info.sp.type = PT_SP_FUNCTION;
			    node->info.sp.param_list = $6;
			    node->info.sp.ret_type = $9;
			    node->info.sp.java_method = $14;
			  }

			$$ = node;

		DBG_PRINT}}
	| CREATE IdName
		{{

			push_msg (MSGCAT_SYNTAX_INVALID_CREATE);
			csql_yyerror_explicit (@2.first_line, @2.first_column);

		DBG_PRINT}}
	| CREATE					/* 1 */
		{					/* 2 */
			PT_NODE* qc = parser_new_node(this_parser, PT_CREATE_ENTITY);
			parser_push_hint_node(qc);
		}
	  opt_hint_list					/* 3 */
	  opt_global					/* 4 */
	  of_class_table_type				/* 5 */
	  class_name					/* 6 */
	  LIKE						/* 7 */
	  class_name					/* 8 */
	  opt_on_node					/* 9 */
		{{

			PT_NODE *qc = parser_pop_hint_node ();

			if($4 == 0 && $9 != NULL)
			  {
			    PT_ERRORm (this_parser, qc, MSGCAT_SET_PARSER_SYNTAX,
					MSGCAT_SYNTAX_MISSING_GLOABL_KEYWORD);
			  }

			if (qc)
			  {
			    qc->info.create_entity.entity_name = $6;
			    qc->info.create_entity.entity_type = PT_CLASS;
			    qc->info.create_entity.create_like = $8;

			    qc->info.create_entity.global_entity = (PT_MISC_TYPE) $4;
			    qc->info.create_entity.on_node = $9;
			  }

			$$ = qc;

		DBG_PRINT}}
	| CREATE					/* 1 */
		{					/* 2 */
			PT_NODE* qc = parser_new_node(this_parser, PT_CREATE_ENTITY);
			parser_push_hint_node(qc);
		}
	  opt_hint_list					/* 3 */
	  opt_global					/* 4 */
	  of_class_table_type				/* 5 */
	  class_name					/* 6 */
	  '('						/* 7 */
	  LIKE						/* 8 */
	  class_name					/* 9 */
	  ')'						/* 10 */
	  opt_on_node					/* 11 */
		{{

			PT_NODE *qc = parser_pop_hint_node ();

			if($4 == 0 && $11 != NULL)
			  {
			    PT_ERRORm (this_parser, qc, MSGCAT_SET_PARSER_SYNTAX,
					MSGCAT_SYNTAX_MISSING_GLOABL_KEYWORD);
			  }

			if (qc)
			  {
			    qc->info.create_entity.entity_name = $6;
			    qc->info.create_entity.entity_type = PT_CLASS;
			    qc->info.create_entity.create_like = $9;

			    qc->info.create_entity.global_entity = (PT_MISC_TYPE) $4;
			    qc->info.create_entity.on_node = $11;
			  }

			$$ = qc;

		DBG_PRINT}}
	;

opt_serial_option_list
	: /* empty */
		{{
			container_10 ctn;
			memset(&ctn, 0x00, sizeof(container_10));
			$$ = ctn;
		}}
	| serial_option_list
		{{
			$$ = $1;
		}}
	;

serial_option_list
	: serial_option_list of_serial_option
		{{
			/* container order
			 * 1: start_val
			 *
			 * 2: increment_val,
			 *
			 * 3: max_val,
			 * 4: no_max,
			 *
			 * 5: min_val,
			 * 6: no_min,
			 *
			 * 7: cyclic,
			 * 8: no_cyclic,
			 *
			 * 9: cached_num_val,
			 * 10: no_cache,
			 */

			container_10 ctn = $1;

			PT_NODE* node = pt_top(this_parser);
			switch(TO_NUMBER (CONTAINER_AT_0($2)))
			  {
			  case SERIAL_START:
				if (ctn.c1 != NULL)
				  {
				    PT_ERRORmf (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
						MSGCAT_SEMANTIC_SERIAL_DUPLICATE_ATTR, "start");
				  }

				ctn.c1 = CONTAINER_AT_1($2);
				break;

			  case SERIAL_INC:
				if (ctn.c2 != NULL)
				  {
				    PT_ERRORmf (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
						MSGCAT_SEMANTIC_SERIAL_DUPLICATE_ATTR, "increment");
				  }

				ctn.c2 = CONTAINER_AT_1($2);
				break;

			  case SERIAL_MAX:
				if (ctn.c3 != NULL || TO_NUMBER(ctn.c4) != 0)
				  {
				    PT_ERRORmf (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
						MSGCAT_SEMANTIC_SERIAL_DUPLICATE_ATTR, "max");
				  }

				ctn.c3 = CONTAINER_AT_1($2);
				ctn.c4 = CONTAINER_AT_2($2);
				break;

			  case SERIAL_MIN:
				if (ctn.c5 != NULL || TO_NUMBER(ctn.c6) != 0)
				  {
				    PT_ERRORmf (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
						MSGCAT_SEMANTIC_SERIAL_DUPLICATE_ATTR, "min");
				  }

				ctn.c5 = CONTAINER_AT_1($2);
				ctn.c6 = CONTAINER_AT_2($2);
				break;

			  case SERIAL_CYCLE:
				if (TO_NUMBER(ctn.c7) != 0 || TO_NUMBER(ctn.c8) != 0)
				  {
				    PT_ERRORmf (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
						MSGCAT_SEMANTIC_SERIAL_DUPLICATE_ATTR, "cycle");
				  }

				ctn.c7 = CONTAINER_AT_1($2);
				ctn.c8 = CONTAINER_AT_2($2);
				break;

			  case SERIAL_CACHE:
				if (TO_NUMBER(ctn.c9) != 0 || TO_NUMBER(ctn.c10) != 0)
				  {
				    PT_ERRORmf (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
						MSGCAT_SEMANTIC_SERIAL_DUPLICATE_ATTR, "cache");
				  }

				ctn.c9 = CONTAINER_AT_1($2);
				ctn.c10 = CONTAINER_AT_2($2);
				break;
			  }

			$$ = ctn;

		DBG_PRINT}}
	| of_serial_option
		{{
			/* container order
			 * 1: start_val
			 *
			 * 2: increment_val,
			 *
			 * 3: max_val,
			 * 4: no_max,
			 *
			 * 5: min_val,
			 * 6: no_min,
			 *
			 * 7: cyclic,
			 * 8: no_cyclic,
			 *
			 * 9: cached_num_val,
			 * 10: no_cache,
			 */

			container_10 ctn;
			memset(&ctn, 0x00, sizeof(container_10));

			switch(TO_NUMBER (CONTAINER_AT_0($1)))
			  {
			  case SERIAL_START:
				ctn.c1 = CONTAINER_AT_1($1);
				break;

			  case SERIAL_INC:
				ctn.c2 = CONTAINER_AT_1($1);
				break;

			  case SERIAL_MAX:
				ctn.c3 = CONTAINER_AT_1($1);
				ctn.c4 = CONTAINER_AT_2($1);
				break;

			  case SERIAL_MIN:
				ctn.c5 = CONTAINER_AT_1($1);
				ctn.c6 = CONTAINER_AT_2($1);
				break;

			  case SERIAL_CYCLE:
				ctn.c7 = CONTAINER_AT_1($1);
				ctn.c8 = CONTAINER_AT_2($1);
				break;

			  case SERIAL_CACHE:
				ctn.c9 = CONTAINER_AT_1($1);
				ctn.c10 = CONTAINER_AT_2($1);
				break;
			  }

			$$ = ctn;

		DBG_PRINT}}
	;

of_serial_option
	: serial_start
		{{
			container_3 ctn;
			SET_CONTAINER_3(ctn, FROM_NUMBER(SERIAL_START), $1, NULL);
			$$ = ctn;
		DBG_PRINT}}
	| serial_increment
		{{
			container_3 ctn;
			SET_CONTAINER_3(ctn, FROM_NUMBER(SERIAL_INC), $1, NULL);
			$$ = ctn;
		DBG_PRINT}}
	| serial_min
		{{
			container_3 ctn;
			SET_CONTAINER_3(ctn, FROM_NUMBER(SERIAL_MIN), CONTAINER_AT_0($1), CONTAINER_AT_1($1));
			$$ = ctn;
		DBG_PRINT}}
	| serial_max
		{{
			container_3 ctn;
			SET_CONTAINER_3(ctn, FROM_NUMBER(SERIAL_MAX), CONTAINER_AT_0($1), CONTAINER_AT_1($1));
			$$ = ctn;
		DBG_PRINT}}
	| of_cycle_nocycle
		{{
			container_3 ctn;
			SET_CONTAINER_3(ctn, FROM_NUMBER(SERIAL_CYCLE), CONTAINER_AT_0($1), CONTAINER_AT_1($1));
			$$ = ctn;
		DBG_PRINT}}
	| of_cached_num
		{{
			container_3 ctn;
			SET_CONTAINER_3(ctn, FROM_NUMBER(SERIAL_CACHE), CONTAINER_AT_0($1), CONTAINER_AT_1($1));
			$$ = ctn;
		DBG_PRINT}}
	;


opt_replace
	: /* empty */
		{{

			$$ = PT_CREATE_SELECT_NO_ACTION;

		DBG_PRINT}}
	| REPLACE
		{{

			$$ = PT_CREATE_SELECT_REPLACE;

		DBG_PRINT}}
	;

alter_stmt
	: ALTER						/* 1 */
		{					/* 2 */
			PT_NODE* node = parser_new_node(this_parser, PT_ALTER);
			parser_push_hint_node(node);
		}
	  opt_hint_list					/* 3 */
	  opt_global					/* 4 */
	  opt_class_type				/* 5 */
	  only_class_name				/* 6 */
		{{

			PT_NODE *node = parser_pop_hint_node ();
			int entity_type = ($5 == PT_EMPTY ? PT_MISC_DUMMY : $5);

			if (node)
			  {
			    node->info.alter.entity_type = entity_type;
			    node->info.alter.entity_name = $6;

			    node->info.alter.global_entity = (PT_MISC_TYPE) $4;
			  }

			parser_save_alter_node (node);

		DBG_PRINT}}
	  alter_clause_cubrid_specific
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    pt_gather_constraints (this_parser, node);
			  }
			$$ = node;

		DBG_PRINT}}
	| ALTER						/* 1 */
		{					/* 2 */
			PT_NODE* node = parser_new_node(this_parser, PT_ALTER);
			parser_push_hint_node(node);
		}
	  opt_hint_list					/* 3 */
	  opt_global					/* 4 */
	  opt_class_type				/* 5 */
	  only_class_name				/* 6 */
	  alter_clause_list				/* 7 */
		{{

			PT_NODE *node = NULL;
			int entity_type = ($5 == PT_EMPTY ? PT_MISC_DUMMY : $5);

			for (node = $7; node != NULL; node = node->next)
			  {
			    node->info.alter.entity_type = entity_type;
			    node->info.alter.entity_name = parser_copy_tree (this_parser, $6);
			    pt_gather_constraints (this_parser, node);
			    if (node->info.alter.code == PT_RENAME_ENTITY)
			      {
					node->info.alter.alter_clause.rename.element_type = entity_type;
					/* We can get the original name from info.alter.entity_name */
					node->info.alter.alter_clause.rename.old_name = NULL;
			      }

			    node->info.alter.global_entity = (PT_MISC_TYPE) $4;
			  }
			parser_free_tree (this_parser, $6);

			$$ = $7;

		DBG_PRINT}}
	| ALTER						/* 1 */
	  opt_global					/* 2 */
	  USER						/* 3 */
	  identifier					/* 4 */
	  PASSWORD					/* 5 */
	  char_string_literal				/* 6 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_ALTER_USER);

			if (node)
			  {
			    node->info.alter_user.user_name = $4;
			    node->info.alter_user.password = $6;

			    node->info.alter_user.global_entity = (PT_MISC_TYPE) $2;
			  }

			$$ = node;

		DBG_PRINT}}
	| ALTER
	  TRIGGER
	  identifier_list
	  trigger_status_or_priority
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_ALTER_TRIGGER);

			PT_NODE *list = parser_new_node (this_parser, PT_TRIGGER_SPEC_LIST);
			if (list)
			  {
			    list->info.trigger_spec_list.trigger_name_list = $3;
			  }

			if (node)
			  {
			    node->info.alter_trigger.trigger_spec_list = list;
			    node->info.alter_trigger.trigger_status = TO_NUMBER (CONTAINER_AT_0 ($4));
			    node->info.alter_trigger.trigger_priority = CONTAINER_AT_1 ($4);
			  }

			$$ = node;

		DBG_PRINT}}
	| ALTER						/* 1 */
	  opt_global					/* 2 */
	  SERIAL					/* 3 */
	  identifier					/* 4 */
	  opt_serial_option_list			/* 5 */
		{{
			/* container order
			 * 0: start_val
			 * 1: increment_val,
			 * 2: max_val,
			 * 3: no_max,
			 * 4: min_val,
			 * 5: no_min,
			 * 6: cyclic,
			 * 7: no_cyclic,
			 * 8: cached_num_val,
			 * 9: no_cache,
			 */

			PT_NODE *serial_name = $4;
			PT_NODE *start_val = CONTAINER_AT_0 ($5);
			PT_NODE *increment_val = CONTAINER_AT_1 ($5);
			PT_NODE *max_val = CONTAINER_AT_2 ($5);
			int no_max = TO_NUMBER (CONTAINER_AT_3 ($5));
			PT_NODE *min_val = CONTAINER_AT_4 ($5);
			int no_min = TO_NUMBER (CONTAINER_AT_5 ($5));
			int cyclic = TO_NUMBER (CONTAINER_AT_6 ($5));
			int no_cyclic = TO_NUMBER (CONTAINER_AT_7 ($5));
			PT_NODE *cached_num_val = CONTAINER_AT_8 ($5);
			int no_cache = TO_NUMBER (CONTAINER_AT_9 ($5));

			PT_NODE *node = parser_new_node (this_parser, PT_ALTER_SERIAL);
			if (node)
			  {
			    node->info.serial.serial_name = serial_name;
			    node->info.serial.increment_val = increment_val;
			    node->info.serial.start_val = start_val;
			    node->info.serial.max_val = max_val;
			    node->info.serial.no_max = no_max;
			    node->info.serial.min_val = min_val;
			    node->info.serial.no_min = no_min;
			    node->info.serial.cyclic = cyclic;
			    node->info.serial.no_cyclic = no_cyclic;
			    node->info.serial.cached_num_val = cached_num_val;
			    node->info.serial.no_cache = no_cache;

			    node->info.serial.global_entity = (PT_MISC_TYPE) $2;
			  }

			$$ = node;

			if (!start_val && !increment_val && !max_val && !min_val
			    && cyclic == 0 && no_max == 0 && no_min == 0
			    && no_cyclic == 0)
			  {
			    PT_ERRORmf (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
					MSGCAT_SEMANTIC_SERIAL_ALTER_NO_OPTION, 0);
			  }

		DBG_PRINT}}
	| ALTER						/* 1 */
		{					/* 2 */
			PT_NODE* node = parser_new_node(this_parser, PT_ALTER_INDEX);
			parser_push_hint_node(node);
		}
	  opt_hint_list					/* 3 */
  	  opt_global					/* 4 */
	  opt_reverse					/* 5 */
	  opt_unique					/* 6 */
	  INDEX						/* 7 */
	  ON_						/* 8 */
	  only_class_name				/* 9 */
	  index_column_name_list			/* 10 */
	  REBUILD					/* 11 */
		{{

			PT_NODE *node = parser_pop_hint_node ();

			node->info.index.reverse = $5;
			node->info.index.unique = $6;

			node->info.index.indexed_class = $9;
			node->info.index.column_names = $10;

			node->info.index.global_entity = (PT_MISC_TYPE) $4;

			$$ = node;

		DBG_PRINT}}
	| ALTER						/* 1 */
		{					/* 2 */
			PT_NODE* node = parser_new_node(this_parser, PT_ALTER_INDEX);
			parser_push_hint_node(node);
		}
	  opt_hint_list					/* 3 */
  	  opt_global					/* 4 */
	  opt_reverse					/* 5 */
	  opt_unique					/* 6 */
	  INDEX						/* 7 */
	  identifier					/* 8 */
	  ON_						/* 9 */
	  only_class_name				/* 10 */
	  opt_index_column_name_list			/* 11 */
	  REBUILD					/* 12 */
		{{

			PT_NODE *node = parser_pop_hint_node ();

			node->info.index.reverse = $5;
			node->info.index.unique = $6;

			node->info.index.index_name = $8;
			node->info.index.indexed_class = $10;
			node->info.index.column_names = $11;

			node->info.index.global_entity = (PT_MISC_TYPE) $4;

			$$ = node;

		DBG_PRINT}}
	| ALTER						/* 1 */
		{					/* 2 */
			PT_NODE* node = parser_new_node(this_parser, PT_ALTER_INDEX);
			parser_push_hint_node(node);
		}
	  opt_hint_list					/* 3 */
  	  opt_global					/* 4 */
	  opt_reverse					/* 5 */
	  opt_unique					/* 6 */
	  INDEX						/* 7 */
	  identifier					/* 8 */
	  REBUILD					/* 9 */
		{{

			PT_NODE *node = parser_pop_hint_node ();

			node->info.index.reverse = $5;
			node->info.index.unique = $6;

			node->info.index.index_name = $8;

			node->info.index.global_entity = (PT_MISC_TYPE) $4;

			$$ = node;

		DBG_PRINT}}
	| ALTER						/* 1 */
	  VIEW						/* 2 */
 	  opt_global					/* 3 */
	  class_name					/* 4 */
	  AS						/* 5 */
	  csql_query					/* 6 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_ALTER);
			if (node)
			  {
			    node->info.alter.entity_type = PT_VCLASS;
			    node->info.alter.entity_name = $4;
			    node->info.alter.code = PT_MODIFY_QUERY;
			    node->info.alter.alter_clause.query.query = $6;
			    node->info.alter.alter_clause.query.query_no_list = NULL;

			    node->info.alter.global_entity = (PT_MISC_TYPE) $4;

			    pt_gather_constraints (this_parser, node);
			  }
			$$ = node;

		DBG_PRINT}}
	;

alter_clause_list
	: alter_clause_list ',' prepare_alter_node alter_clause_for_alter_list
		{{

			$$ = parser_make_link ($1, parser_get_alter_node ());

		DBG_PRINT}}
	| /* The first node in the list is the one that was pushed for hints. */
		{

			PT_NODE *node = parser_pop_hint_node ();
			parser_save_alter_node (node);
		}
	 alter_clause_for_alter_list
		{{

			$$ = parser_get_alter_node ();

		DBG_PRINT}}
	;

prepare_alter_node
	: /* empty */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_ALTER);
			parser_save_alter_node (node);

		DBG_PRINT}}
	;

only_class_name
	: ONLY class_name
		{ $$ = $2; }
	| class_name
		{ $$ = $1; }
	;

rename_stmt
	: RENAME					/* 1 */
	  opt_global					/* 2 */
	  opt_class_type				/* 3 */
	  rename_class_list				/* 4 */
		{{

			PT_NODE *node = NULL;
			int entity_type = ($3 == PT_EMPTY ? PT_CLASS : $3);

			for (node = $4; node != NULL; node = node->next)
			  {
			    node->info.rename.entity_type = entity_type;

			    node->info.rename.global_entity = (PT_MISC_TYPE) $2;
			  }

			$$ = $4;

		DBG_PRINT}}
	| RENAME TRIGGER class_name AS class_name
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_RENAME_TRIGGER);

			if (node)
			  {
			    node->info.rename_trigger.new_name = $5;
			    node->info.rename_trigger.old_name = $3;
			  }

			$$ = node;

		DBG_PRINT}}
	;

rename_class_list
	: rename_class_list ',' rename_class_pair
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| rename_class_pair
		{{

			$$ = $1;

		DBG_PRINT}}
	;

rename_class_pair
	:  only_class_name as_or_to only_class_name
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_RENAME);
			if (node)
			  {
			    node->info.rename.old_name = $1;
			    node->info.rename.new_name = $3;
			    node->info.rename.entity_type = PT_CLASS;
			  }

			$$ = node;

		DBG_PRINT}}
	;

as_or_to
	: AS
	| TO
	;

truncate_stmt
	: TRUNCATE opt_table_type class_spec
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_TRUNCATE);
			if (node)
			  {
			    node->info.truncate.spec = $3;
			  }

			$$ = node;

		DBG_PRINT}}
	;

do_stmt
	: DO expression_
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_DO);
			if (node)
			  {
			    node->info.do_.expr = $2;
			  }

			$$ = node;

		DBG_PRINT}}
	;

drop_stmt
	: DROP						/* 1 */
	  opt_global					/* 2 */
	  opt_class_type				/* 3 */
	  class_spec_list				/* 4 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_DROP);
			if (node)
			  {
			    node->info.drop.spec_list = $4;

			    if ($3 == PT_EMPTY)
			      node->info.drop.entity_type = PT_MISC_DUMMY;
			    else
			      node->info.drop.entity_type = $3;

			    node->info.drop.global_entity = (PT_MISC_TYPE) $2;
			  }

			$$ = node;

		DBG_PRINT}}
	| DROP						/* 1 */
		{					/* 2 */
			PT_NODE* node = parser_new_node(this_parser, PT_DROP_INDEX);
			parser_push_hint_node(node);
		}
	  opt_hint_list					/* 3 */
	  opt_global					/* 4 */
	  opt_reverse					/* 5 */
	  opt_unique					/* 6 */
	  INDEX						/* 7 */
	  ON_						/* 8 */
	  only_class_name				/* 9 */
	  index_column_name_list			/* 10 */
		{{

			PT_NODE *node = parser_pop_hint_node ();

			node->info.index.reverse = $5;
			node->info.index.unique = $6;

			node->info.index.indexed_class = $9;
			node->info.index.column_names = $10;

			node->info.index.global_entity = (PT_MISC_TYPE) $4;
			$$ = node;

		DBG_PRINT}}
	| DROP						/* 1 */
		{					/* 2 */
			PT_NODE* node = parser_new_node(this_parser, PT_DROP_INDEX);
			parser_push_hint_node(node);
		}
	  opt_hint_list					/* 3 */
	  opt_global					/* 4 */
	  opt_reverse					/* 5 */
	  opt_unique					/* 6 */
	  INDEX						/* 7 */
	  identifier					/* 8 */
	  ON_						/* 9 */
	  only_class_name				/* 10 */
	  opt_index_column_name_list			/* 11 */
		{{

			PT_NODE *node = parser_pop_hint_node ();

			node->info.index.reverse = $5;
			node->info.index.unique = $6;

			node->info.index.index_name = $8;
			node->info.index.indexed_class = $10;
			node->info.index.column_names = $11;

			node->info.index.global_entity = (PT_MISC_TYPE) $4;

			$$ = node;

		DBG_PRINT}}
	| DROP						/* 1 */
		{					/* 2 */
			PT_NODE* node = parser_new_node(this_parser, PT_DROP_INDEX);
			parser_push_hint_node(node);
		}
	  opt_hint_list					/* 3 */
	  opt_global					/* 4 */
	  opt_reverse					/* 5 */
	  opt_unique					/* 6 */
	  INDEX						/* 7 */
	  identifier					/* 8 */
		{{

			PT_NODE *node = parser_pop_hint_node ();

			node->info.index.reverse = $5;
			node->info.index.unique = $6;

			node->info.index.index_name = $8;

			node->info.index.global_entity = (PT_MISC_TYPE) $4;

			$$ = node;

		DBG_PRINT}}
	| DROP						/* 1 */
	  opt_global					/* 2 */
	  USER						/* 3 */
	  identifier					/* 4 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_DROP_USER);

			if (node)
			  {
			    node->info.drop_user.user_name = $4;

			    node->info.drop_user.global_entity = (PT_MISC_TYPE) $2;
			  }

			$$ = node;

		DBG_PRINT}}
	| DROP TRIGGER identifier_list
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_DROP_TRIGGER);

			PT_NODE *list = parser_new_node (this_parser, PT_TRIGGER_SPEC_LIST);
			if (list)
			  {
			    list->info.trigger_spec_list.trigger_name_list = $3;
			  }

			if (node)
			  {
			    node->info.drop_trigger.trigger_spec_list = list;
			  }

			$$ = node;

		DBG_PRINT}}
	| DROP DEFERRED TRIGGER trigger_spec_list
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_REMOVE_TRIGGER);

			if (node)
			  {
			    node->info.remove_trigger.trigger_spec_list = $4;
			  }

			$$ = node;

		DBG_PRINT}}
	| DROP VARIABLE_ identifier_list
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_DROP_VARIABLE);
			if (node)
			  node->info.drop_variable.var_names = $3;
			$$ = node;

		DBG_PRINT}}
	| DROP						/* 1 */
	  opt_global					/* 2 */
	  SERIAL					/* 3 */
	  identifier					/* 4 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_DROP_SERIAL);
			if (node)
			{
			  node->info.serial.serial_name = $4;

			  node->info.serial.global_entity = (PT_MISC_TYPE) $2;
			}
			$$ = node;

		DBG_PRINT}}
	| DROP PROCEDURE identifier_list
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_DROP_STORED_PROCEDURE);

			if (node)
			  {
			    node->info.sp.name = $3;
			    node->info.sp.type = PT_SP_PROCEDURE;
			  }


			$$ = node;

		DBG_PRINT}}
	| DROP FUNCTION identifier_list
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_DROP_STORED_PROCEDURE);

			if (node)
			  {
			    node->info.sp.name = $3;
			    node->info.sp.type = PT_SP_FUNCTION;
			  }


			$$ = node;

		DBG_PRINT}}
	| deallocate_or_drop PREPARE identifier
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_DEALLOCATE_PREPARE);

			if (node)
			  {
			    node->info.prepare.name = $3;
			  }


			$$ = node;

		DBG_PRINT}}
	;

deallocate_or_drop
	: DEALLOCATE
	| DROP
	;

schema_sync_stmt
	: SCHEMA_SYNC			/* 1 */
	  char_string_literal		/* 2 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SCHEMA_SYNC);\
			if (node)
			  {
			    node->info.schema_sync.node_name = $2;
			  }

			$$ = node;
		DBG_PRINT}}
	;

register_stmt
	: REGISTER			/* 1 */
	  opt_node			/* 2 */
	  char_string_literal		/* 3 */
	  char_string_literal		/* 4 */
	  opt_port			/* 5 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_REGISTER_NODE);
			if (node)
			  {
			    node->info.register_node.on_node = $3;
			    node->info.register_node.host_name = $4;
			    node->info.register_node.port = $5;
			  }

			$$ = node;

		DBG_PRINT}}
	| UNREGISTER			/* 1 */
	  opt_node			/* 2 */
	  char_string_literal		/* 3 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_UNREGISTER_NODE);
			if (node)
			  {
			    node->info.register_node.on_node = $3;
			    node->info.register_node.host_name = NULL;
			    node->info.register_node.port = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	;


opt_node
	: /* empty */
	| NODE
	;

opt_port
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| unsigned_int32
		{{

			$$ = $1;

		DBG_PRINT}}
	;



opt_reverse
	: /* empty */
		{{

			parser_save_is_reverse (false);
			$$ = false;

		DBG_PRINT}}
	| REVERSE
		{{

			parser_save_is_reverse (true);
			$$ = true;

		DBG_PRINT}}
	;

opt_unique
	: /* empty */
		{{

			$$ = false;

		DBG_PRINT}}
	| UNIQUE
		{{

			$$ = true;

		DBG_PRINT}}
	;

opt_index_column_name_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| index_column_name_list
		{{

			$$ = $1;

		DBG_PRINT}}
	;

index_column_name_list
	: '(' index_column_name_list_sub ')'
		{{

			$$ = $2;

		DBG_PRINT}}
	;

index_column_name_list_sub
	: index_column_name_list_sub ',' index_column_name
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| index_column_name
		{{

			$$ = $1;

		DBG_PRINT}}
	;

index_column_name
	: identifier
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SORT_SPEC);
			if (node)
			  {
			    if (parser_get_is_reverse ())
			      node->info.sort_spec.asc_or_desc = PT_DESC;
			    else
			      node->info.sort_spec.asc_or_desc = PT_ASC;
			    node->info.sort_spec.expr = $1;
			  }
			$$ = node;

		DBG_PRINT}}
	| identifier ASC
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SORT_SPEC);
			if (node)
			  {
			    if (parser_get_is_reverse ())
			      node->info.sort_spec.asc_or_desc = PT_DESC;
			    else
			      node->info.sort_spec.asc_or_desc = PT_ASC;
			    node->info.sort_spec.expr = $1;
			  }
			$$ = node;

		DBG_PRINT}}
	| identifier DESC
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SORT_SPEC);
			if (node)
			  {
			    node->info.sort_spec.asc_or_desc = PT_DESC;
			    node->info.sort_spec.expr = $1;
			  }
			$$ = node;

		DBG_PRINT}}
	;

update_statistics_stmt
	: UPDATE STATISTICS ON_ only_class_name_list
		{{

			PT_NODE *ups = parser_new_node (this_parser, PT_UPDATE_STATS);
			if (ups)
			  {
			    ups->info.update_stats.class_list = $4;
			    ups->info.update_stats.all_classes = 0;
			  }
			$$ = ups;

		DBG_PRINT}}
	| UPDATE STATISTICS ON_ ALL CLASSES
		{{

			PT_NODE *ups = parser_new_node (this_parser, PT_UPDATE_STATS);
			if (ups)
			  {
			    ups->info.update_stats.class_list = NULL;
			    ups->info.update_stats.all_classes = 1;
			  }
			$$ = ups;

		DBG_PRINT}}
	| UPDATE STATISTICS ON_ CATALOG CLASSES
		{{

			PT_NODE *ups = parser_new_node (this_parser, PT_UPDATE_STATS);
			if (ups)
			  {
			    ups->info.update_stats.class_list = NULL;
			    ups->info.update_stats.all_classes = -1;
			  }
			$$ = ups;

		DBG_PRINT}}
	;

only_class_name_list
	: only_class_name_list ',' only_class_name
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| only_class_name
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_of_to_eq
	: /* empty */
	| TO
	| '='
	;

opt_level_spec
	: ON_
		{{

			PT_NODE *val = parser_new_node (this_parser, PT_VALUE);
			if (val)
			  val->info.value.data_value.i = -1;
			$$ = val;

		DBG_PRINT}}
	| OFF_
		{{

			PT_NODE *val = parser_new_node (this_parser, PT_VALUE);
			if (val)
			  val->info.value.data_value.i = 0;
			$$ = val;

		DBG_PRINT}}
	| unsigned_integer
		{{

			$$ = $1;

		DBG_PRINT}}
	| param_
		{{

			$$ = $1;

		DBG_PRINT}}
	| host_param_input
		{{

			$$ = $1;

		DBG_PRINT}}
	;

char_string_literal_list
	: char_string_literal_list ',' char_string_literal
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| char_string_literal
		{{

			$$ = $1;

		DBG_PRINT}}
	;

table_spec_list
	: table_spec_list  ',' table_spec
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| table_spec
		{{

			$$ = $1;

		DBG_PRINT}}
	;

extended_table_spec_list
	: extended_table_spec_list ',' table_spec
		{{

			container_2 ctn;
			PT_NODE *n1 = CONTAINER_AT_0 ($1);
			PT_NODE *n2 = $3;
			int number = TO_NUMBER (CONTAINER_AT_1 ($1));
			SET_CONTAINER_2 (ctn, parser_make_link (n1, n2), FROM_NUMBER (number));
			$$ = ctn;

		DBG_PRINT}}
	| extended_table_spec_list join_table_spec
		{{

			container_2 ctn;
			PT_NODE *n1 = CONTAINER_AT_0 ($1);
			PT_NODE *n2 = $2;
			SET_CONTAINER_2 (ctn, parser_make_link (n1, n2), FROM_NUMBER (1));
			$$ = ctn;

		DBG_PRINT}}
	| table_spec
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, $1, FROM_NUMBER (0));
			$$ = ctn;

		DBG_PRINT}}
	;

join_table_spec
	: CROSS JOIN table_spec
		{{

			PT_NODE *sopt = $3;
			if (sopt)
			  sopt->info.spec.join_type = PT_JOIN_CROSS;
			$$ = sopt;

		DBG_PRINT}}
	| opt_of_inner_left_right JOIN table_spec join_condition
		{{

			PT_NODE *sopt = $3;
			bool natural = false;

			if (sopt)
			  {
			    sopt->info.spec.natural = natural;
			    sopt->info.spec.join_type = $1;
			    sopt->info.spec.on_cond = $4;
			  }
			$$ = sopt;
			parser_restore_pseudoc ();

		DBG_PRINT}}
	;

join_condition
	: ON_
		{{
			parser_save_and_set_pseudoc (0);
			parser_save_and_set_wjc (1);
			parser_save_and_set_ic (1);
		DBG_PRINT}}
	  search_condition
		{{
			parser_restore_wjc ();
			parser_restore_ic ();
			$$ = $3;
		DBG_PRINT}}


	;

opt_of_inner_left_right
	: /* empty */
		{{

			$$ = PT_JOIN_INNER;

		DBG_PRINT}}
	| INNER opt_outer
		{{

			$$ = PT_JOIN_INNER;

		DBG_PRINT}}
	| LEFT opt_outer
		{{

			$$ = PT_JOIN_LEFT_OUTER;

		DBG_PRINT}}
	| RIGHT opt_outer
		{{

			$$ = PT_JOIN_RIGHT_OUTER;

		DBG_PRINT}}
	;

opt_outer
	: /* empty */
	| OUTER
	;

table_spec
	: class_spec opt_as_identifier_attr_name opt_with_read_uncommitted
		{{

			PT_NODE *ent = $1;
			if (ent)
			  {
			    ent->info.spec.range_var = CONTAINER_AT_0 ($2);
			    ent->info.spec.as_attr_list = CONTAINER_AT_1 ($2);

			    if ($3)
			      {
				ent->info.spec.lock_hint |= LOCKHINT_READ_UNCOMMITTED;
			      }
			  }


			$$ = ent;

		DBG_PRINT}}
	| meta_class_spec opt_as_identifier_attr_name
		{{

			PT_NODE *ent = $1;
			if (ent)
			  {
			    ent->info.spec.range_var = CONTAINER_AT_0 ($2);
			    ent->info.spec.as_attr_list = CONTAINER_AT_1 ($2);

			    parser_remove_dummy_select (&ent);
			  }
			$$ = ent;

		DBG_PRINT}}
	| subquery opt_as_identifier_attr_name
		{{

			PT_NODE *ent = parser_new_node (this_parser, PT_SPEC);
			if (ent)
			  {
			    ent->info.spec.derived_table = $1;
			    ent->info.spec.derived_table_type = PT_IS_SUBQUERY;

			    ent->info.spec.range_var = CONTAINER_AT_0 ($2);
			    ent->info.spec.as_attr_list = CONTAINER_AT_1 ($2);

			    parser_remove_dummy_select (&ent);
			  }
			$$ = ent;

		DBG_PRINT}}
	| TABLE '(' expression_ ')' opt_as_identifier_attr_name
		{{

			PT_NODE *ent = parser_new_node (this_parser, PT_SPEC);
			if (ent)
			  {
			    ent->info.spec.derived_table = $3;
			    ent->info.spec.derived_table_type = PT_IS_SET_EXPR;

			    ent->info.spec.range_var = CONTAINER_AT_0 ($5);
			    ent->info.spec.as_attr_list = CONTAINER_AT_1 ($5);

			    parser_remove_dummy_select (&ent);
			  }
			$$ = ent;

		DBG_PRINT}}
	;

opt_with_read_uncommitted
	: /* empty */
		{{

			$$ = 0;

		DBG_PRINT}}
	| WITH '(' READ UNCOMMITTED ')'
		{{

			$$ = 1;

		DBG_PRINT}}
	;

opt_as_identifier_attr_name
	: /* empty */
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, NULL, NULL);
			$$ = ctn;

		DBG_PRINT}}
	| opt_as identifier '(' identifier_list ')'
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, $2, $4);
			$$ = ctn;

		DBG_PRINT}}
	| opt_as identifier
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, $2, NULL);
			$$ = ctn;

		DBG_PRINT}}
	;

opt_as
	: /* empty */
	| AS
	;

class_spec_list
	: class_spec_list  ',' class_spec
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| class_spec
		{{

			$$ = $1;

		DBG_PRINT}}
	;

class_spec
	: only_all_class_spec
		{{

			$$ = $1;

		DBG_PRINT}}
	| '(' only_all_class_spec_list ')'
		{{

			$$ = $2;

		DBG_PRINT}}
	;

only_all_class_spec_list
	: only_all_class_spec_list ',' only_all_class_spec
		{{

			PT_NODE *result = parser_make_link ($1, $3);
			PT_NODE *p = parser_new_node (this_parser, PT_SPEC);
			if (p)
			  p->info.spec.entity_name = result;
			$$ = p;

		DBG_PRINT}}
	| only_all_class_spec
		{{

			$$ = $1;

		DBG_PRINT}}
	;

meta_class_spec
	: CLASS only_class_name
		{{

			PT_NODE *ocs = parser_new_node (this_parser, PT_SPEC);
			if (ocs)
			  {
			    ocs->info.spec.entity_name = $2;
			    ocs->info.spec.only_all = PT_ONLY;
			    ocs->info.spec.meta_class = PT_CLASS;
			  }

			if (ocs)
			  ocs->info.spec.meta_class = PT_META_CLASS;
			$$ = ocs;

		DBG_PRINT}}
	;

only_all_class_spec
	: only_class_name
		{{

			PT_NODE *ocs = parser_new_node (this_parser, PT_SPEC);
			if (ocs)
			  {
			    ocs->info.spec.entity_name = $1;
			    ocs->info.spec.only_all = PT_ONLY;
			    ocs->info.spec.meta_class = PT_CLASS;
			  }

			$$ = ocs;

		DBG_PRINT}}
	| ALL class_name '(' EXCEPT class_spec_list ')'
		{{

			PT_NODE *acs = parser_new_node (this_parser, PT_SPEC);
			if (acs)
			  {
			    acs->info.spec.entity_name = $2;
			    acs->info.spec.only_all = PT_ALL;
			    acs->info.spec.meta_class = PT_CLASS;

			    acs->info.spec.except_list = $5;
			  }
			$$ = acs;

		DBG_PRINT}}
	| ALL class_name
		{{

			PT_NODE *acs = parser_new_node (this_parser, PT_SPEC);
			if (acs)
			  {
			    acs->info.spec.entity_name = $2;
			    acs->info.spec.only_all = PT_ALL;
			    acs->info.spec.meta_class = PT_CLASS;
			  }

			$$ = acs;

		DBG_PRINT}}
	;

class_name
	: identifier '.' identifier
		{{

			PT_NODE *user_node = $1;
			PT_NODE *name_node = $3;

			if (name_node != NULL && user_node != NULL)
			  {
			    name_node->info.name.resolved = pt_append_string (this_parser, NULL,
			                                                      user_node->info.name.original);
			  }
			if (user_node != NULL)
			  {
			    parser_free_tree (this_parser, user_node);
			  }

			$$ = name_node;

		DBG_PRINT}}
	| identifier
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_class_type
	: /* empty */
		{{

			$$ = PT_EMPTY;

		DBG_PRINT}}
	| VCLASS
		{{

			$$ = PT_VCLASS;

		DBG_PRINT}}
	| VIEW
		{{

			$$ = PT_VCLASS;

		DBG_PRINT}}
	| CLASS
		{{

			$$ = PT_CLASS;

		DBG_PRINT}}
	| TABLE
		{{

			$$ = PT_CLASS;

		DBG_PRINT}}
	| TYPE
		{{

			$$ = PT_ADT;

		DBG_PRINT}}
	;

opt_table_type
	: /* empty */
		{{

			$$ = PT_EMPTY;

		DBG_PRINT}}
	| CLASS
		{{

			$$ = PT_CLASS;

		DBG_PRINT}}
	| TABLE
		{{

			$$ = PT_CLASS;

		DBG_PRINT}}
	;

alter_clause_for_alter_list
	: ADD       alter_add_clause_for_alter_list
	| DROP     alter_drop_clause_for_alter_list
	| DROP     alter_drop_clause_mysql_specific
	| RENAME alter_rename_clause_mysql_specific
	| RENAME alter_rename_clause_allow_multiple opt_resolution_list_for_alter
	| ALTER  alter_column_clause_mysql_specific
	|     alter_partition_clause_for_alter_list
	;

alter_clause_cubrid_specific
	: ADD       alter_add_clause_cubrid_specific opt_resolution_list_for_alter
	| DROP     alter_drop_clause_cubrid_specific opt_resolution_list_for_alter
	| RENAME alter_rename_clause_cubrid_specific opt_resolution_list_for_alter
	| CHANGE alter_change_clause_cubrid_specific
	| ADD       alter_add_clause_for_alter_list      resolution_list_for_alter
	| DROP     alter_drop_clause_for_alter_list      resolution_list_for_alter
	| inherit_resolution_list
		{{

			PT_NODE *alt = parser_get_alter_node ();

			if (alt)
			  {
			    alt->info.alter.code = PT_RENAME_RESOLUTION;
			    alt->info.alter.super.resolution_list = $1;
			  }

		DBG_PRINT}}
	;

opt_resolution_list_for_alter
	: /* [empty] */
	| resolution_list_for_alter
	;

resolution_list_for_alter
	: inherit_resolution_list
		{{

			PT_NODE *alt = parser_get_alter_node ();

			if (alt)
			  {
			    alt->info.alter.super.resolution_list = $1;
			  }

		DBG_PRINT}}
	;

alter_rename_clause_mysql_specific
	: opt_to only_class_name
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_RENAME_ENTITY;
			    node->info.alter.alter_clause.rename.new_name = $2;
			  }

		DBG_PRINT}}
	;

alter_rename_clause_allow_multiple
	: opt_of_attr_column_method opt_class identifier AS identifier
		{{

			PT_NODE *node = parser_get_alter_node ();
			PT_MISC_TYPE etyp = $1;

			if (node)
			  {
			    node->info.alter.code = PT_RENAME_ATTR_MTHD;

			    if (etyp == PT_EMPTY)
			      etyp = PT_ATTRIBUTE;

			    node->info.alter.alter_clause.rename.element_type = etyp;
			    if ($2)
			      node->info.alter.alter_clause.rename.meta = PT_META_ATTR;
			    else
			      node->info.alter.alter_clause.rename.meta = PT_NORMAL;

			    node->info.alter.alter_clause.rename.new_name = $5;
			    node->info.alter.alter_clause.rename.old_name = $3;
			  }

		DBG_PRINT}}
	;

alter_rename_clause_cubrid_specific
	: FUNCTION opt_identifier OF opt_class identifier AS identifier
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_RENAME_ATTR_MTHD;
			    node->info.alter.alter_clause.rename.element_type = PT_FUNCTION_RENAME;
			    if ($4)
			      node->info.alter.alter_clause.rename.meta = PT_META_ATTR;
			    else
			      node->info.alter.alter_clause.rename.meta = PT_NORMAL;

			    node->info.alter.alter_clause.rename.new_name = $7;
			    node->info.alter.alter_clause.rename.mthd_name = $5;
			    node->info.alter.alter_clause.rename.old_name = $2;
			  }

		DBG_PRINT}}
	| File file_path_name AS file_path_name
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_RENAME_ATTR_MTHD;
			    node->info.alter.alter_clause.rename.element_type = PT_FILE_RENAME;
			    node->info.alter.alter_clause.rename.new_name = $4;
			    node->info.alter.alter_clause.rename.old_name = $2;
			  }

		DBG_PRINT}}
	;

opt_of_attr_column_method
	: /* empty */
		{{

			$$ = PT_EMPTY;

		DBG_PRINT}}
	| ATTRIBUTE
		{{

			$$ = PT_ATTRIBUTE;

		DBG_PRINT}}
	| COLUMN
		{{

			$$ = PT_ATTRIBUTE;

		DBG_PRINT}}
	| METHOD
		{{

			$$ = PT_METHOD;

		DBG_PRINT}}
	;

opt_class
	: /* empty */
		{{

			$$ = 0;

		DBG_PRINT}}
	| CLASS
		{{

			$$ = 1;

		DBG_PRINT}}
	;

opt_identifier
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| identifier
		{{

			$$ = $1;

		DBG_PRINT}}
	;

alter_add_clause_for_alter_list
	: PARTITION add_partition_clause
	| CLASS ATTRIBUTE
		{ parser_attr_type = PT_META_ATTR; }
	  '(' attr_def_list ')'
		{ parser_attr_type = PT_NORMAL; }
		{{

			PT_NODE *node = parser_get_alter_node ();
			if (node)
			  {
			    node->info.alter.code = PT_ADD_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.attr_def_list = $5;
			  }

		DBG_PRINT}}
	| CLASS ATTRIBUTE
		{ parser_attr_type = PT_META_ATTR; }
	  attr_def
		{ parser_attr_type = PT_NORMAL; }
		{{

			PT_NODE *node = parser_get_alter_node ();
			if (node)
			  {
			    node->info.alter.code = PT_ADD_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.attr_def_list = $4;
			  }

		DBG_PRINT}}
	| opt_of_column_attribute
	  		{ allow_attribute_ordering = true; }
	  '(' attr_def_list ')'
	  		{ allow_attribute_ordering = false; }
		{{

			PT_NODE *node = parser_get_alter_node ();
			if (node)
			  {
			    node->info.alter.code = PT_ADD_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.attr_def_list = $4;
			  }

		DBG_PRINT}}
	| opt_of_column_attribute
			{ allow_attribute_ordering = true; }
	  attr_def
	  		{ allow_attribute_ordering = false; }
		{{

			PT_NODE *node = parser_get_alter_node ();
			if (node)
			  {
			    node->info.alter.code = PT_ADD_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.attr_def_list = $3;
			  }

		DBG_PRINT}}
	;

alter_add_clause_cubrid_specific
	: File method_file_list
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_ADD_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.mthd_file_list = $2;
			  }

		DBG_PRINT}}
	| METHOD method_def_list
		{{

			PT_NODE *node = parser_get_alter_node ();
			if (node)
			  {
			    node->info.alter.code = PT_ADD_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.mthd_def_list = $2;
			  }

		DBG_PRINT}}
	| METHOD method_def_list File method_file_list
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_ADD_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.mthd_file_list = $4;
			    node->info.alter.alter_clause.attr_mthd.mthd_def_list = $2;
			  }

		DBG_PRINT}}
	| SUPERCLASS only_class_name_list
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_ADD_SUPCLASS;
			    node->info.alter.super.sup_class_list = $2;
			  }

		DBG_PRINT}}
	| QUERY csql_query
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_ADD_QUERY;
			    node->info.alter.alter_clause.query.query = $2;
			  }

		DBG_PRINT}}
	| CLASS ATTRIBUTE
		{ parser_attr_type = PT_META_ATTR; }
	  attr_def_list_with_commas
		{ parser_attr_type = PT_NORMAL; }
		{{

			PT_NODE *node = parser_get_alter_node ();
			if (node)
			  {
			    node->info.alter.code = PT_ADD_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.attr_def_list = $4;
			  }

		DBG_PRINT}}
	| opt_of_column_attribute attr_def_list_with_commas
		{{

			PT_NODE *node = parser_get_alter_node ();
			if (node)
			  {
			    node->info.alter.code = PT_ADD_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.attr_def_list = $2;
			  }

		DBG_PRINT}}
	;

opt_of_column_attribute
	: /* empty */
	| COLUMN
	| ATTRIBUTE
	;

add_partition_clause
	: PARTITIONS unsigned_integer
		{{

			PT_NODE *node = parser_get_alter_node ();
			node->info.alter.code = PT_ADD_HASHPARTITION;
			node->info.alter.alter_clause.partition.size = $2;

		DBG_PRINT}}
	| '(' partition_def_list ')'
		{{

			PT_NODE *node = parser_get_alter_node ();
			node->info.alter.code = PT_ADD_PARTITION;
			node->info.alter.alter_clause.partition.parts = $2;

		DBG_PRINT}}
	;

alter_drop_clause_mysql_specific
	: opt_reverse opt_unique index_or_key identifier
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_DROP_INDEX_CLAUSE;
			    node->info.alter.alter_clause.index.reverse = $1;
			    node->info.alter.alter_clause.index.unique = $2;
			    node->info.alter.constraint_list = $4;
			  }

		DBG_PRINT}}
	| PRIMARY KEY
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_DROP_PRIMARY_CLAUSE;
			  }

		DBG_PRINT}}
	| FOREIGN KEY identifier
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_DROP_FK_CLAUSE;
			    node->info.alter.constraint_list = $3;
			  }

		DBG_PRINT}}
	;

alter_drop_clause_for_alter_list
	: opt_of_attr_column_method normal_or_class_attr
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_DROP_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.attr_mthd_name_list = $2;
			  }

		DBG_PRINT}}
	| CONSTRAINT identifier
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_DROP_CONSTRAINT;
			    node->info.alter.constraint_list = $2;
			  }

		DBG_PRINT}}
	| PARTITION identifier_list
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_DROP_PARTITION;
			    node->info.alter.alter_clause.partition.name_list = $2;
			  }

		DBG_PRINT}}
	;

alter_drop_clause_cubrid_specific
	: opt_of_attr_column_method normal_or_class_attr_list_with_commas
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_DROP_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.attr_mthd_name_list = $2;
			  }

		DBG_PRINT}}
	| File method_file_list
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_DROP_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.mthd_file_list = $2;
			  }

		DBG_PRINT}}
	| SUPERCLASS only_class_name_list
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_DROP_SUPCLASS;
			    node->info.alter.super.sup_class_list = $2;
			  }

		DBG_PRINT}}
	| QUERY query_number_list
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_DROP_QUERY;
			    node->info.alter.alter_clause.query.query_no_list = $2;
			  }

		DBG_PRINT}}
	| QUERY
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_DROP_QUERY;
			    node->info.alter.alter_clause.query.query_no_list = NULL;
			  }

		DBG_PRINT}}
	;

normal_or_class_attr_list_with_commas
	: normal_or_class_attr_list_with_commas ',' normal_or_class_attr
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| normal_or_class_attr ',' normal_or_class_attr
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	;

alter_change_clause_cubrid_specific
	: METHOD method_def_list
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_MODIFY_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.mthd_def_list = $2;
			  }

		DBG_PRINT}}
	| CLASS ATTRIBUTE
		{ parser_attr_type = PT_META_ATTR; }
	  attr_def_list
		{ parser_attr_type = PT_NORMAL; }
		{{

			PT_NODE *node = parser_get_alter_node ();
			if (node)
			  {
			    node->info.alter.code = PT_MODIFY_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.attr_def_list = $4;
			  }

		DBG_PRINT}}
	| opt_of_column_attribute attr_def_list
		{{

			PT_NODE *node = parser_get_alter_node ();
			if (node)
			  {
			    node->info.alter.code = PT_MODIFY_ATTR_MTHD;
			    node->info.alter.alter_clause.attr_mthd.attr_def_list = $2;
			  }

		DBG_PRINT}}
	| alter_attr_default_value_list
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_MODIFY_DEFAULT;
			    node->info.alter.alter_clause.ch_attr_def.attr_name_list =
			      CONTAINER_AT_0 ($1);
			    node->info.alter.alter_clause.ch_attr_def.data_default_list =
			      CONTAINER_AT_1 ($1);
			  }

		DBG_PRINT}}
	| QUERY unsigned_integer csql_query
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_MODIFY_QUERY;
			    node->info.alter.alter_clause.query.query = $3;
			    node->info.alter.alter_clause.query.query_no_list = $2;
			  }

		DBG_PRINT}}
	| QUERY csql_query
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_MODIFY_QUERY;
			    node->info.alter.alter_clause.query.query = $2;
			    node->info.alter.alter_clause.query.query_no_list = NULL;
			  }

		DBG_PRINT}}
	| File file_path_name AS file_path_name
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_RENAME_ATTR_MTHD;
			    node->info.alter.alter_clause.rename.element_type = PT_FILE_RENAME;
			    node->info.alter.alter_clause.rename.new_name = $4;
			    node->info.alter.alter_clause.rename.old_name = $2;
			  }

		DBG_PRINT}}
	;

alter_attr_default_value_list
	: alter_attr_default_value_list ',' normal_or_class_attr DEFAULT expression_
		{{

			parser_make_link (CONTAINER_AT_0 ($1), $3);
			parser_make_link (CONTAINER_AT_1 ($1), $5);
			$$ = $1;

		DBG_PRINT}}
	| normal_or_class_attr DEFAULT expression_
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, $1, $3);
			$$ = ctn;

		DBG_PRINT}}
	;


normal_or_class_attr
	: opt_class identifier
		{{

			if ($1)
			  $2->info.name.meta_class = PT_META_ATTR;
			else
			  $2->info.name.meta_class = PT_NORMAL;

			$$ = $2;

		DBG_PRINT}}
	;

query_number_list
	: query_number_list ',' unsigned_integer
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| unsigned_integer
		{{

			$$ = $1;

		DBG_PRINT}}
	;

alter_column_clause_mysql_specific
	: normal_column_or_class_attribute SET DEFAULT literal_w_o_param
		{{

			PT_NODE *node = parser_get_alter_node ();

			if (node)
			  {
			    node->info.alter.code = PT_ALTER_DEFAULT;
			    node->info.alter.alter_clause.ch_attr_def.attr_name_list = $1;
			    node->info.alter.alter_clause.ch_attr_def.data_default_list = $4;
			  }

		DBG_PRINT}}
	;

normal_column_or_class_attribute
	: opt_of_column_attribute identifier
		{{

			PT_NODE * node = $2;
			if (node)
			  {
			    node->info.name.meta_class = PT_NORMAL;
			  }
			$$ = node;

		DBG_PRINT}}
	| CLASS ATTRIBUTE identifier
		{{

			PT_NODE * node = $3;
			if (node)
			  {
			    node->info.name.meta_class = PT_META_ATTR;
			  }
			$$ = node;

		DBG_PRINT}}
	;

insert_or_replace_stmt
	: insert_name_clause insert_stmt_value_clause on_duplicate_key_update
		{{

			PT_NODE *ins = $1;

			if (ins)
			  {
			    PT_NODE *assignment = $3;
			    PT_NODE *spec = ins->info.insert.spec;

			    if (assignment != NULL && spec != NULL)
			      {
				ins->info.insert.on_dup_key_update =
				  pt_dup_key_update_stmt (this_parser, spec, assignment);
			      }

			    ins->info.insert.value_clauses = $2;
			  }

			$$ = ins;

		DBG_PRINT}}
	| insert_name_clause insert_stmt_value_clause into_clause_opt
		{{

			PT_NODE *ins = $1;

			if (ins)
			  {
			    ins->info.insert.value_clauses = $2;
			    ins->info.insert.into_var = $3;
			  }

			$$ = ins;

		DBG_PRINT}}
	| replace_name_clause insert_stmt_value_clause into_clause_opt
		{{

			PT_NODE *ins = $1;

			if (ins)
			  {
			    ins->info.insert.value_clauses = $2;
			    ins->info.insert.into_var = $3;
			  }

			$$ = ins;

		DBG_PRINT}}
	| insert_set_stmt on_duplicate_key_update
		{{

			PT_NODE *ins = $1;

			if (ins)
			  {
			    PT_NODE *assignment = $2;
			    PT_NODE *spec = ins->info.insert.spec;

			    if (assignment != NULL && spec != NULL)
			      {
				ins->info.insert.on_dup_key_update =
				  pt_dup_key_update_stmt (this_parser, spec, assignment);
			      }
			  }

			$$ = ins;

		DBG_PRINT}}
	| insert_set_stmt into_clause_opt
		{{

			PT_NODE *ins = $1;

			if (ins)
			  {
			    ins->info.insert.into_var = $2;
			  }

			$$ = ins;

		DBG_PRINT}}
	| replace_set_stmt into_clause_opt
		{{

			PT_NODE *ins = $1;

			if (ins)
			  {
			    ins->info.insert.into_var = $2;
			  }

			$$ = ins;

		DBG_PRINT}}
	;

insert_set_stmt
	: insert_stmt_keyword
	  insert_set_stmt_header
		{{
			$$ = $2;
		}}
	;

replace_set_stmt
	: replace_stmt_keyword
	  insert_set_stmt_header
		{{
			$$ = $2;
		}}
	;

insert_stmt_keyword
	: INSERT
		{
			PT_NODE* ins = parser_new_node (this_parser, PT_INSERT);
			parser_push_hint_node (ins);
		}
	;

replace_stmt_keyword
	: REPLACE
		{
			PT_NODE* ins = parser_new_node (this_parser, PT_INSERT);
			if (ins)
			  {
			    ins->info.insert.do_replace = true;
			  }
			parser_push_hint_node (ins);
		}
	;

insert_set_stmt_header
	: opt_hint_list
	  opt_into
	  only_class_name
	  SET
	  insert_assignment_list
		{{

			PT_NODE *ins = parser_pop_hint_node ();
			PT_NODE *ocs = parser_new_node (this_parser, PT_SPEC);
			PT_NODE *nls = pt_node_list (this_parser, PT_IS_VALUE, CONTAINER_AT_1 ($5));

			if (ocs)
			  {
			    ocs->info.spec.entity_name = $3;
			    ocs->info.spec.only_all = PT_ONLY;
			    ocs->info.spec.meta_class = PT_CLASS;
			  }

			if (ins)
			  {
			    ins->info.insert.spec = ocs;
			    ins->info.insert.attr_list = CONTAINER_AT_0 ($5);
			    ins->info.insert.value_clauses = nls;
			  }

			$$ = ins;

		DBG_PRINT}}
	;

insert_assignment_list
	: insert_assignment_list ',' identifier '=' expression_
		{{

			parser_make_link (CONTAINER_AT_0 ($1), $3);
			parser_make_link (CONTAINER_AT_1 ($1), $5);

			$$ = $1;

		DBG_PRINT}}
	| insert_assignment_list ',' identifier '=' DEFAULT
		{{
			PT_NODE *arg = parser_copy_tree (this_parser, $3);

			if (arg)
			  {
			    pt_set_fill_default_in_path_expression (arg);
			  }
			parser_make_link (CONTAINER_AT_0 ($1), $3);
			parser_make_link (CONTAINER_AT_1 ($1),
					  parser_make_expression (PT_DEFAULTF, arg, NULL, NULL));

			$$ = $1;

		DBG_PRINT}}
	| identifier '=' expression_
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, $1, $3);

			$$ = ctn;

		DBG_PRINT}}
	| identifier '=' DEFAULT
		{{

			container_2 ctn;
			PT_NODE *arg = parser_copy_tree (this_parser, $1);

			if (arg)
			  {
			    pt_set_fill_default_in_path_expression (arg);
			  }
			SET_CONTAINER_2 (ctn, $1,
			  parser_make_expression (PT_DEFAULTF, arg, NULL, NULL));

			$$ = ctn;

		DBG_PRINT}}
	;

on_duplicate_key_update
	: ON_ DUPLICATE_ KEY UPDATE
	  update_assignment_list
		{{

			$$ = $5;

		DBG_PRINT}}
	;

insert_expression
	: insert_name_clause insert_expression_value_clause
		{{

			PT_NODE *ins = $1;

			if (ins)
			  {
			    ins->info.insert.value_clauses = $2;
			  }

			$$ = ins;

		DBG_PRINT}}
	| '(' insert_name_clause insert_expression_value_clause into_clause_opt ')'
		{{

			PT_NODE *ins = $2;

			if (ins)
			  {
			    ins->info.insert.value_clauses = $3;
			    ins->info.insert.into_var = $4;
			  }

			$$ = ins;

		DBG_PRINT}}
	;

insert_name_clause
	: insert_stmt_keyword
	  insert_name_clause_header
		{{
			$$ = $2;
		}}
	;

replace_name_clause
	: replace_stmt_keyword
	  insert_name_clause_header
		{{
			$$ = $2;
		}}
	;

insert_name_clause_header
	: opt_hint_list
	  opt_into
	  only_class_name
	  opt_attr_list
		{{

			PT_NODE *ins = parser_pop_hint_node ();
			PT_NODE *ocs = parser_new_node (this_parser, PT_SPEC);

			if (ocs)
			  {
			    ocs->info.spec.entity_name = $3;
			    ocs->info.spec.only_all = PT_ONLY;
			    ocs->info.spec.meta_class = PT_CLASS;
			  }

			if (ins)
			  {
			    ins->info.insert.spec = ocs;
			    ins->info.insert.attr_list = $4;
			  }

			$$ = ins;

		DBG_PRINT}}
	;


opt_attr_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| '(' ')'
		{{

			$$ = NULL;

		DBG_PRINT}}
	| '(' identifier_list ')'
		{{

			$$ = $2;

		DBG_PRINT}}
	;


insert_stmt_value_clause
	: insert_expression_value_clause
		{{

			$$ = $1;

		DBG_PRINT}}
	| csql_query
		{{

			PT_NODE *nls = pt_node_list (this_parser, PT_IS_SUBQUERY, $1);
			$$ = nls;

		DBG_PRINT}}
	;

insert_expression_value_clause
	: of_value_values insert_value_clause_list
		{{

			$$ = $2;

		DBG_PRINT}}
	| DEFAULT opt_values
		{{

			PT_NODE *nls = pt_node_list (this_parser, PT_IS_DEFAULT_VALUE, NULL);
			$$ = nls;

		DBG_PRINT}}
	;

of_value_values
	: VALUE
	| VALUES
	;

opt_values
	: /* [empty] */
	| VALUES
	;

opt_into
	: /* [empty] */
	| INTO
	;

into_clause_opt
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| INTO to_param
		{{

			$$ = $2;

		DBG_PRINT}}
	| TO to_param
		{{

			$$ = $2;

		DBG_PRINT}}
	;

insert_value_clause_list
	: insert_value_clause_list ',' insert_value_clause
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| insert_value_clause
		{{

			$$ = $1;

		DBG_PRINT}}
	;

insert_value_clause
	: '(' insert_value_list ')'
		{{

			PT_NODE *nls = pt_node_list (this_parser, PT_IS_VALUE, $2);
			$$ = nls;

		DBG_PRINT}}
	| '('')'
		{{

			PT_NODE *nls = NULL;

			if (PRM_COMPAT_MODE == COMPAT_MYSQL)
			  {
			    nls = pt_node_list (this_parser, PT_IS_DEFAULT_VALUE, NULL);
			  }
			else
			  {
			    nls = pt_node_list (this_parser, PT_IS_VALUE, NULL);
			  }

			$$ = nls;

		DBG_PRINT}}
	| DEFAULT opt_values
		{{

			PT_NODE *nls = pt_node_list (this_parser, PT_IS_DEFAULT_VALUE, NULL);
			$$ = nls;

		DBG_PRINT}}
	;

insert_value_list
	: insert_value_list ',' insert_value
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| insert_value
		{{

			$$ = $1;

		DBG_PRINT}}
	;

insert_value
	: select_stmt
		{{

			$$ = $1;

		DBG_PRINT}}
	| expression_
		{{

			$$ = $1;

		DBG_PRINT}}
	| DEFAULT
		{{

			/* The argument will be filled in later, when the
			   corresponding column name is known.
			   See fill_in_insert_default_function_arguments(). */
			$$ = parser_make_expression (PT_DEFAULTF, NULL, NULL, NULL);

		DBG_PRINT}}
	;


update_head
	: UPDATE
		{
			PT_NODE* node = parser_new_node(this_parser, PT_UPDATE);
			parser_push_hint_node(node);
		}
	  opt_hint_list
	;

update_stmt
	: update_head
	  of_class_spec_meta_class_spec
	  opt_as_identifier
	  SET
	  update_assignment_list
	  opt_of_where_cursor
	  opt_using_index_clause
	  opt_upd_del_limit_clause
		{{

			PT_NODE *node = parser_pop_hint_node ();
			$2->info.spec.range_var = $3;

			node->info.update.spec = $2;
			node->info.update.assignment = $5;

			if (CONTAINER_AT_0 ($6))
			  node->info.update.search_cond = CONTAINER_AT_1 ($6);
			else
			  node->info.update.cursor_name = CONTAINER_AT_1 ($6);

			node->info.update.using_index = $7;

			/* set LIMIT node */
			node->info.update.limit = $8;
			if (node->info.update.limit
			    && node->info.update.search_cond)
			  {
			    /* For UPDATE statements that have LIMIT clause don't allow
			     * inst_num in search condition
			     */
			    bool instnum_flag = false;
			    (void) parser_walk_tree (this_parser, node->info.update.search_cond,
						     pt_check_instnum_pre, NULL,
						     pt_check_instnum_post, &instnum_flag);
			    if (instnum_flag)
			      {
				PT_ERRORmf(this_parser, node->info.update.search_cond,
					   MSGCAT_SET_PARSER_SEMANTIC,
					   MSGCAT_SEMANTIC_NOT_ALLOWED_IN_LIMIT_CLAUSE, "INST_NUM()/ROWNUM");
			      }
			  }
			else if (node->info.update.limit
				 && node->info.update.cursor_name)
			  {
			    /* It makes no sense to allow LIMIT for UPDATE statements
			     * that use cursor
			     */
			    PT_ERRORmf(this_parser, node->info.update.search_cond,
				       MSGCAT_SET_PARSER_SEMANTIC,
				       MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "LIMIT");
			  }

			$$ = node;

		DBG_PRINT}}
	| update_head
	  OBJECT
	  from_param
	  SET
	  update_assignment_list
		{{

			PT_NODE *node = parser_pop_hint_node ();
			if (node)
			  {
			    node->info.update.object_parameter = $3;
			    node->info.update.assignment = $5;
			  }

			$$ = node;

		DBG_PRINT}}
	;


opt_of_where_cursor
	: /* empty */
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, 0, NULL);
			$$ = ctn;

		DBG_PRINT}}
	| WHERE
		{
			parser_save_and_set_ic(1);
			DBG_PRINT
		}
	  search_condition
	  	{
			parser_restore_ic();
			DBG_PRINT
		}
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (1), $3);
			$$ = ctn;

		DBG_PRINT}}
	| WHERE CURRENT OF identifier
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (0), $4);
			$$ = ctn;

		DBG_PRINT}}
	;


of_class_spec_meta_class_spec
	: class_spec
		{{

			$$ = $1;

		DBG_PRINT}}
	| meta_class_spec
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_as_identifier
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| AS identifier
		{{

			$$ = $2;

		DBG_PRINT}}
	| identifier
		{{

			$$ = $1;

		DBG_PRINT}}
	;

update_assignment_list
	: update_assignment_list ',' update_assignment
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| update_assignment
		{{

			$$ = $1;

		DBG_PRINT}}
	;

update_assignment
	: path_expression '=' expression_
		{{

			$$ = parser_make_expression (PT_ASSIGN, $1, $3, NULL);

		DBG_PRINT}}
	| simple_path_id '=' DEFAULT
		{{

			PT_NODE *node, *node_df = NULL;
			node = parser_copy_tree (this_parser, $1);
			if (node)
			  {
			    pt_set_fill_default_in_path_expression (node);
			    node_df = parser_make_expression (PT_DEFAULTF, node, NULL, NULL);
			  }
			$$ = parser_make_expression (PT_ASSIGN, $1, node_df, NULL);

		DBG_PRINT}}
	| paren_path_expression_set '=' primary
		{{

			PT_NODE *exp = parser_make_expression (PT_ASSIGN, $1, NULL, NULL);
			PT_NODE *arg1, *arg2, *list, *tmp;
			PT_NODE *e1, *e2 = NULL, *e1_next, *e2_next;
			bool is_subquery = false;
			arg1 = $1;
			arg2 = $3;

						/* primary is parentheses expr set value */
			if (arg2->node_type == PT_VALUE &&
			    (arg2->type_enum == PT_TYPE_NULL || arg2->type_enum == PT_TYPE_EXPR_SET))
			  {

			    /* flatten multi-column assignment expr */
			    if (arg1->node_type == PT_EXPR)
			      {
				/* get elements and free set node */
				e1 = arg1->info.expr.arg1;
				arg1->info.expr.arg1 = NULL;	/* cut-off link */
				parser_free_node (this_parser, exp);	/* free exp, arg1 */

				if (arg2->type_enum == PT_TYPE_NULL)
				  {
				    ;			/* nop */
				  }
				else
				  {
				    e2 = arg2->info.value.data_value.set;
				    arg2->info.value.data_value.set = NULL;	/* cut-off link */
				  }
				parser_free_node (this_parser, arg2);

				list = NULL;		/* init */
				for (; e1; e1 = e1_next)
				  {
				    e1_next = e1->next;
				    e1->next = NULL;
				    if (arg2->type_enum == PT_TYPE_NULL)
				      {
					if ((e2 = parser_new_node (this_parser, PT_VALUE)) == NULL)
					  break;	/* error */
					e2->type_enum = PT_TYPE_NULL;
				      }
				    else
				      {
					if (e2 == NULL)
					  break;	/* error */
				      }
				    e2_next = e2->next;
				    e2->next = NULL;

				    tmp = parser_new_node (this_parser, PT_EXPR);
				    if (tmp)
				      {
					tmp->info.expr.op = PT_ASSIGN;
					tmp->info.expr.arg1 = e1;
					tmp->info.expr.arg2 = e2;
				      }
				    list = parser_make_link (tmp, list);

				    e2 = e2_next;
				  }

				/* expression number check */
				if (e1 || e2)
				  {
				    PT_ERRORf (this_parser, list,
					       "check syntax at %s, different number of elements in each expression.",
					       pt_show_binopcode (PT_ASSIGN));
				  }

				$$ = list;
			      }
			    else
			      {
				/* something wrong */
				exp->info.expr.arg2 = arg2;
				$$ = exp;
			      }
			  }
			else
			  {
			    if (pt_is_query (arg2))
			      {
				/* primary is subquery. go ahead */
				is_subquery = true;
			      }

			    exp->info.expr.arg1 = arg1;
			    exp->info.expr.arg2 = arg2;

			    $$ = exp;
			    PICE (exp);

			    /* unknown error check */
			    if (is_subquery == false)
			      {
				PT_ERRORf (this_parser, exp, "check syntax at %s",
					   pt_show_binopcode (PT_ASSIGN));
			      }
			  }

		DBG_PRINT}}
	;

paren_path_expression_set
	: '(' path_expression_list ')'
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_EXPR);

			if (p)
			  {
			    p->info.expr.op = PT_PATH_EXPR_SET;
			    p->info.expr.paren_type = 1;
			    p->info.expr.arg1 = $2;
			  }

			$$ = p;

		DBG_PRINT}}
	;

path_expression_list
	: path_expression_list ',' path_expression
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| path_expression
		{{

			$$ = $1;

		DBG_PRINT}}
	;

delete_stmt
	: DELETE_				/* $1 */
		{				/* $2 */
			PT_NODE* node = parser_new_node(this_parser, PT_DELETE);
			parser_push_hint_node(node);
		}
	  opt_hint_list 			/* $3 */
	  opt_class_name 			/* $4 */
	  FROM 					/* $5 */
	  table_spec_list 			/* $6 */
	  opt_of_where_cursor 			/* $7 */
	  opt_using_index_clause 		/* $8 */
	  opt_upd_del_limit_clause		/* $9 */
		{{

			PT_NODE *del = parser_pop_hint_node ();

			if (del)
			  {
			    del->info.delete_.class_name = $4;
			    del->info.delete_.spec = $6;
			    if (TO_NUMBER (CONTAINER_AT_0 ($7)))
			      del->info.delete_.search_cond = CONTAINER_AT_1 ($7);
			    else
			      del->info.delete_.cursor_name = CONTAINER_AT_1 ($7);

			    del->info.delete_.using_index = $8;

			    /* set LIMIT node */
			    del->info.delete_.limit = $9;
			    if (del->info.delete_.limit
				&& del->info.delete_.search_cond)
			      {
				/* For DELETE statements that have LIMIT clause don't allow
				 * inst_num in search condition
				 */
				bool instnum_flag = false;
				(void) parser_walk_tree (this_parser, del->info.delete_.search_cond,
							 pt_check_instnum_pre, NULL,
							 pt_check_instnum_post, &instnum_flag);
				if (instnum_flag)
				  {
				    PT_ERRORmf(this_parser, del->info.delete_.search_cond,
					       MSGCAT_SET_PARSER_SEMANTIC,
					       MSGCAT_SEMANTIC_NOT_ALLOWED_IN_LIMIT_CLAUSE, "INST_NUM()/ROWNUM");
				  }
			      }
			    else if (del->info.delete_.limit
				     && del->info.delete_.cursor_name)
			      {
				/* It makes no sense to allow LIMIT for DELETE statements
				 * that use (Oracle style) cursor
				 */
				PT_ERRORmf(this_parser, del->info.delete_.search_cond,
					   MSGCAT_SET_PARSER_SEMANTIC,
					   MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "LIMIT");
			      }

			  }
			$$ = del;

		DBG_PRINT}}
	;

opt_class_name
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| class_name
		{{

			$$ = $1;

		DBG_PRINT}}
	;


auth_stmt
	 : grant_head opt_with_grant_option
		{{

			PT_NODE *node = $1;
			PT_MISC_TYPE w = PT_NO_GRANT_OPTION;
			if ($2)
			  w = PT_GRANT_OPTION;

			if (node)
			  {
			    node->info.grant.grant_option = w;
			  }

			$$ = node;

		DBG_PRINT}}
	| revoke_cmd on_class_list from_id_list
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_REVOKE);

			if (node)
			  {
			    node->info.revoke.user_list = $3;
			    node->info.revoke.spec_list = $2;
			    node->info.revoke.auth_cmd_list = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	| revoke_cmd from_id_list on_class_list
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_REVOKE);

			if (node)
			  {
			    node->info.revoke.user_list = $2;
			    node->info.revoke.spec_list = $3;
			    node->info.revoke.auth_cmd_list = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	;

revoke_cmd
	: REVOKE
		{ push_msg(MSGCAT_SYNTAX_MISSING_AUTH_COMMAND_LIST); }
	  author_cmd_list
		{ pop_msg(); }
		{ $$ = $3; }
	;

grant_cmd
	: GRANT
		{ push_msg(MSGCAT_SYNTAX_MISSING_AUTH_COMMAND_LIST); }
	  author_cmd_list
		{ pop_msg(); }
		{ $$ = $3; }
	;

grant_head
	: grant_cmd on_class_list to_id_list
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_GRANT);

			if (node)
			  {
			    node->info.grant.user_list = $3;
			    node->info.grant.spec_list = $2;
			    node->info.grant.auth_cmd_list = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	| grant_cmd to_id_list on_class_list
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_GRANT);

			if (node)
			  {
			    node->info.grant.user_list = $2;
			    node->info.grant.spec_list = $3;
			    node->info.grant.auth_cmd_list = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	;

opt_with_grant_option
	: /* empty */
		{{

			$$ = 0;

		DBG_PRINT}}
	| WITH GRANT OPTION
		{{

			$$ = 1;

		DBG_PRINT}}
	;

on_class_list
	: ON_
		{ push_msg(MSGCAT_SYNTAX_MISSING_CLASS_SPEC_LIST); }
	  class_spec_list
		{ pop_msg(); }
		{ $$ = $3; }
	;

to_id_list
	: TO
		{ push_msg(MSGCAT_SYNTAX_MISSING_IDENTIFIER_LIST); }
	  identifier_list
		{ pop_msg(); }
		{ $$ = $3; }
	;

from_id_list
	: FROM
		{ push_msg(MSGCAT_SYNTAX_MISSING_IDENTIFIER_LIST); }
	  identifier_list
		{ pop_msg(); }
		{ $$ = $3; }
	;

author_cmd_list
	: author_cmd_list ',' authorized_cmd
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| authorized_cmd
		{{

			$$ = $1;

		DBG_PRINT}}
	;

authorized_cmd
	: SELECT
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);
			node->info.auth_cmd.auth_cmd = PT_SELECT_PRIV;
			node->info.auth_cmd.attr_mthd_list = NULL;
			$$ = node;

		DBG_PRINT}}
	| INSERT
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_INSERT_PRIV;
			    node->info.auth_cmd.attr_mthd_list = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	| INDEX
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_INDEX_PRIV;
			    node->info.auth_cmd.attr_mthd_list = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	| DELETE_
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_DELETE_PRIV;
			    node->info.auth_cmd.attr_mthd_list = NULL;
			  }

			$$ = node;

		DBG_PRINT}}

	| UPDATE '(' identifier_list ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_UPDATE_PRIV;
			    PT_ERRORmf (this_parser, node, MSGCAT_SET_PARSER_SYNTAX,
					MSGCAT_SYNTAX_ATTR_IN_PRIVILEGE,
					parser_print_tree_list (this_parser, $3));

			    node->info.auth_cmd.attr_mthd_list = $3;
			  }

			$$ = node;

		DBG_PRINT}}
	| UPDATE
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_UPDATE_PRIV;
			    node->info.auth_cmd.attr_mthd_list = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	| ALTER
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_ALTER_PRIV;
			    node->info.auth_cmd.attr_mthd_list = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	| ADD
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_ADD_PRIV;
			    node->info.auth_cmd.attr_mthd_list = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	| DROP
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_DROP_PRIV;
			    node->info.auth_cmd.attr_mthd_list = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	| EXECUTE
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_EXECUTE_PRIV;
			    node->info.auth_cmd.attr_mthd_list = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	| REFERENCES
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_REFERENCES_PRIV;
			    node->info.auth_cmd.attr_mthd_list = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	| ALL PRIVILEGES
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_ALL_PRIV;
			    node->info.auth_cmd.attr_mthd_list = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	| ALL
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_AUTH_CMD);

			if (node)
			  {
			    node->info.auth_cmd.auth_cmd = PT_ALL_PRIV;
			    node->info.auth_cmd.attr_mthd_list = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	;

opt_password
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| PASSWORD
		{ push_msg(MSGCAT_SYNTAX_INVALID_PASSWORD); }
	  char_string_literal
		{ pop_msg(); }
		{{

			$$ = $3;

		DBG_PRINT}}
	;

opt_groups
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| GROUPS
		{ push_msg(MSGCAT_SYNTAX_INVALID_GROUPS); }
	  identifier_list
		{ pop_msg(); }
		{{

			$$ = $3;

		DBG_PRINT}}
	;

opt_members
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| MEMBERS
		{ push_msg(MSGCAT_SYNTAX_INVALID_MEMBERS); }
	  identifier_list
		{ pop_msg(); }
		{{

			$$ = $3;

		DBG_PRINT}}
	;

call_stmt
	: CALL generic_function into_clause_opt
		{{

			PT_NODE *node = $2;
			if (node)
			  {
			    node->info.method_call.call_or_expr = PT_IS_CALL_STMT;
			    node->info.method_call.to_return_var = $3;
			  }

			parser_cannot_prepare = true;
			parser_cannot_cache = true;

			$$ = node;

		DBG_PRINT}}
	;

opt_class_or_normal_attr_def_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| '(' class_or_normal_attr_def_list ')'
		{{

			$$ = $2;

		DBG_PRINT}}
	;

opt_method_def_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| METHOD method_def_list
		{{

			$$ = $2;

		DBG_PRINT}}
	;

opt_method_files
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| File method_file_list
		{{

			$$ = $2;

		DBG_PRINT}}
	;

opt_inherit_resolution_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| inherit_resolution_list
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_table_option_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| table_option_list
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_partition_clause
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| partition_clause
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_create_as_clause
	: /* empty */
		{{

			container_2 ctn;
			SET_CONTAINER_2(ctn, NULL, NULL);
			$$ = ctn;

		DBG_PRINT}}
	| create_as_clause
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_global
	: /* empty */
		{{
			$$ = 0;
		DBG_PRINT}}
	| GLOBAL
		{{
			$$ = PT_GLOBAL;
		DBG_PRINT}}
	;

opt_on_node
	: /* empty */
		{{
			$$ = NULL;
		DBG_PRINT}}
	| ON_ NODE char_string_literal_list
		{{
			$$ = $3;
		DBG_PRINT}}
	;

of_class_table_type
	: CLASS
		{{

			$$ = PT_CLASS;

		DBG_PRINT}}
	| TABLE
		{{

			$$ = PT_CLASS;

		DBG_PRINT}}
	| TYPE
		{{

			$$ = PT_ADT;

		DBG_PRINT}}
	;

of_view_vclass
	: VIEW
	| VCLASS
	;

opt_or_replace
	: /*empty*/
		{{

			$$ = 0;

		DBG_PRINT}}
	| OR REPLACE
		{{

			$$ = 1;

		DBG_PRINT}}
	;

opt_paren_view_attr_def_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| '(' view_attr_def_list ')'
		{{

			$$ = $2;

		DBG_PRINT}}
	;

opt_as_query_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| AS query_list
		{{

			$$ = $2;

		DBG_PRINT}}
	;

opt_with_levels_clause
	: /* empty */
		{{

			$$ = PT_EMPTY;

		DBG_PRINT}}
	| WITH LOCAL CHECK OPTION
		{{

			$$ = PT_LOCAL_CHECK_OPT;

		DBG_PRINT}}
	| WITH CASCADED CHECK OPTION
		{{

			$$ = PT_CASCADED_CHECK_OPT;

		DBG_PRINT}}
	| WITH CHECK OPTION
		{{

			$$ = PT_CASCADED_CHECK_OPT;

		DBG_PRINT}}
	;

query_list
	: query_list ',' csql_query
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| csql_query
		{{

			$$ = $1;

		DBG_PRINT}}
	;

inherit_resolution_list
	: inherit_resolution_list  ',' inherit_resolution
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| INHERIT inherit_resolution
		{{

			$$ = $2;

		DBG_PRINT}}
	;

inherit_resolution
	: opt_class identifier OF identifier AS identifier
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_RESOLUTION);

			if (node)
			  {
			    PT_MISC_TYPE t = PT_NORMAL;

			    if ($1)
			      t = PT_META_ATTR;
			    node->info.resolution.of_sup_class_name = $4;
			    node->info.resolution.attr_mthd_name = $2;
			    node->info.resolution.attr_type = t;
			    node->info.resolution.as_attr_mthd_name = $6;
			  }

			$$ = node;

		DBG_PRINT}}
	| opt_class identifier OF identifier
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_RESOLUTION);

			if (node)
			  {
			    PT_MISC_TYPE t = PT_NORMAL;

			    if ($1)
			      t = PT_META_ATTR;
			    node->info.resolution.of_sup_class_name = $4;
			    node->info.resolution.attr_mthd_name = $2;
			    node->info.resolution.attr_type = t;
			  }

			$$ = node;

		DBG_PRINT}}
	;

table_option_list
	: table_option_list  ',' table_option
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| table_option
		{{

			$$ = $1;

		DBG_PRINT}}
	;

table_option
	: REUSE_OID
		{{

			$$ = pt_table_option (this_parser, PT_TABLE_OPTION_REUSE_OID, NULL);

		DBG_PRINT}}
	;

opt_subtable_clause
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| UNDER only_class_name_list
		{{

			$$ = $2;

		DBG_PRINT}}
	| AS SUBCLASS OF only_class_name_list
		{{

			$$ = $4;

		DBG_PRINT}}
	;

opt_constraint_id
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| CONSTRAINT identifier
		{{

			$$ = $2;

		DBG_PRINT}}
	;

opt_constraint_opt_id
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| CONSTRAINT opt_identifier
		{{

			$$ = $2;

		DBG_PRINT}}
	;

of_unique_foreign_check
	: unique_constraint
		{{

			$$ = $1;

		DBG_PRINT}}
	| foreign_key_constraint
		{{

			$$ = $1;

		DBG_PRINT}}
	| check_constraint
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_constraint_attr_list
	: /* empty */
		{{

			container_4 ctn;
			SET_CONTAINER_4 (ctn, FROM_NUMBER (0), FROM_NUMBER (0), FROM_NUMBER (0),
					 FROM_NUMBER (0));
			$$ = ctn;

		DBG_PRINT}}
	| constraint_attr_list
		{{

			$$ = $1;

		DBG_PRINT}}
	;

constraint_attr_list
	: constraint_attr_list ',' constraint_attr
		{{

			container_4 ctn = $1;
			container_4 ctn_new = $3;

			if (TO_NUMBER (ctn_new.c1))
			  {
			    ctn.c1 = ctn_new.c1;
			    ctn.c2 = ctn_new.c2;
			  }

			if (TO_NUMBER (ctn_new.c3))
			  {
			    ctn.c3 = ctn_new.c3;
			    ctn.c4 = ctn_new.c4;
			  }

			$$ = ctn;

		DBG_PRINT}}
	| constraint_attr
		{{

			$$ = $1;

		DBG_PRINT}}
	;

unique_constraint
	: PRIMARY KEY opt_identifier '(' index_column_identifier_list ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_CONSTRAINT);

			if (node)
			  {
			    node->info.constraint.type = PT_CONSTRAIN_PRIMARY_KEY;
			    node->info.constraint.name = $3;
			    node->info.constraint.un.unique.attrs = $5;
			  }

			$$ = node;

		DBG_PRINT}}
	| UNIQUE opt_of_index_key opt_identifier '(' index_column_identifier_list ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_CONSTRAINT);

			if (node)
			  {
			    node->info.constraint.type = PT_CONSTRAIN_UNIQUE;
			    node->info.constraint.name = $3;
			    node->info.constraint.un.unique.attrs = $5;
			  }

			$$ = node;

		DBG_PRINT}}
	;

foreign_key_constraint
	: FOREIGN 					/* 1 */
	  KEY '(' index_column_identifier_list ')'	/* 2, 3, 4, 5 */
	  REFERENCES					/* 6 */
	  class_name					/* 7 */
	  opt_paren_attr_list				/* 8 */
	  opt_ref_rule_list				/* 9 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_CONSTRAINT);

			if (node)
			  {
			    node->info.constraint.type = PT_CONSTRAIN_FOREIGN_KEY;
			    node->info.constraint.un.foreign_key.attrs = $4;

			    node->info.constraint.un.foreign_key.referenced_attrs = $8;
			    node->info.constraint.un.foreign_key.match_type = PT_MATCH_REGULAR;
			    node->info.constraint.un.foreign_key.delete_action = TO_NUMBER (CONTAINER_AT_0 ($9));	/* delete_action */
			    node->info.constraint.un.foreign_key.update_action = TO_NUMBER (CONTAINER_AT_1 ($9));	/* update_action */
			    node->info.constraint.un.foreign_key.cache_attr = CONTAINER_AT_2 ($9);	/* cache_attr */
			    node->info.constraint.un.foreign_key.referenced_class = $7;
			  }

			$$ = node;

		DBG_PRINT}}
	;

index_column_identifier_list
	: index_column_identifier_list ',' index_column_identifier
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| index_column_identifier
		{{

			$$ = $1;

		DBG_PRINT}}
	;

index_column_identifier
	: identifier opt_asc_or_desc
		{{

			if ($2)
			  {
			    PT_NAME_INFO_SET_FLAG ($1, PT_NAME_INFO_DESC);
			  }
			$$ = $1;

		DBG_PRINT}}
	;

opt_asc_or_desc
	: /* empty */
		{{

			$$ = 0;

		DBG_PRINT}}
	| ASC
		{{

			$$ = 0;

		DBG_PRINT}}
	| DESC
		{{

			$$ = 1;

		DBG_PRINT}}
	;

opt_paren_attr_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| '(' identifier_list ')'
		{{

			$$ = $2;

		DBG_PRINT}}
	;

opt_ref_rule_list
	: /* empty */
		{{

			container_3 ctn;
			SET_CONTAINER_3 (ctn, FROM_NUMBER (PT_RULE_RESTRICT),
					 FROM_NUMBER (PT_RULE_RESTRICT), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| ref_rule_list
		{{

			container_3 ctn = $1;
			if (ctn.c1 == NULL)
			  ctn.c1 = FROM_NUMBER (PT_RULE_RESTRICT);
			if (ctn.c2 == NULL)
			  ctn.c2 = FROM_NUMBER (PT_RULE_RESTRICT);
			$$ = ctn;

		DBG_PRINT}}
	;

ref_rule_list
	: ref_rule_list ON_ DELETE_ CASCADE
		{{

			container_3 ctn = $1;
			if (ctn.c1 != NULL)
			  {
			    push_msg (MSGCAT_SYNTAX_DUPLICATED_REF_RULE);
			    csql_yyerror_explicit (@2.first_line, @2.first_column);
			  }

			ctn.c1 = FROM_NUMBER (PT_RULE_CASCADE);
			$$ = ctn;

		DBG_PRINT}}
	| ref_rule_list ON_ DELETE_ NO ACTION
		{{

			container_3 ctn = $1;
			if (ctn.c1 != NULL)
			  {
			    push_msg (MSGCAT_SYNTAX_DUPLICATED_REF_RULE);
			    csql_yyerror_explicit (@2.first_line, @2.first_column);
			  }

			ctn.c1 = FROM_NUMBER (PT_RULE_NO_ACTION);
			$$ = ctn;

		DBG_PRINT}}
	| ref_rule_list ON_ DELETE_ RESTRICT
		{{

			container_3 ctn = $1;
			if (ctn.c1 != NULL)
			  {
			    push_msg (MSGCAT_SYNTAX_DUPLICATED_REF_RULE);
			    csql_yyerror_explicit (@2.first_line, @2.first_column);
			  }

			ctn.c1 = FROM_NUMBER (PT_RULE_RESTRICT);
			$$ = ctn;

		DBG_PRINT}}
	| ref_rule_list ON_ DELETE_ SET Null
		{{

			container_3 ctn = $1;
			if (ctn.c1 != NULL)
			  {
			    push_msg (MSGCAT_SYNTAX_DUPLICATED_REF_RULE);
			    csql_yyerror_explicit (@2.first_line, @2.first_column);
			  }

			ctn.c1 = FROM_NUMBER (PT_RULE_SET_NULL);
			$$ = ctn;

		DBG_PRINT}}
	| ref_rule_list ON_ UPDATE NO ACTION
		{{

			container_3 ctn = $1;
			if (ctn.c2 != NULL)
			  {
			    push_msg (MSGCAT_SYNTAX_DUPLICATED_REF_RULE);
			    csql_yyerror_explicit (@2.first_line, @2.first_column);
			  }

			ctn.c2 = FROM_NUMBER (PT_RULE_NO_ACTION);
			$$ = ctn;

		DBG_PRINT}}
	| ref_rule_list ON_ UPDATE RESTRICT
		{{

			container_3 ctn = $1;
			if (ctn.c2 != NULL)
			  {
			    push_msg (MSGCAT_SYNTAX_DUPLICATED_REF_RULE);
			    csql_yyerror_explicit (@2.first_line, @2.first_column);
			  }

			ctn.c2 = FROM_NUMBER (PT_RULE_RESTRICT);
			$$ = ctn;

		DBG_PRINT}}
	| ref_rule_list ON_ UPDATE SET Null
		{{

			container_3 ctn = $1;
			if (ctn.c2 != NULL)
			  {
			    push_msg (MSGCAT_SYNTAX_DUPLICATED_REF_RULE);
			    csql_yyerror_explicit (@2.first_line, @2.first_column);
			  }

			ctn.c2 = FROM_NUMBER (PT_RULE_SET_NULL);
			$$ = ctn;

		DBG_PRINT}}
	| ref_rule_list ON_ CACHE OBJECT identifier
		{{

			container_3 ctn = $1;
			if (ctn.c3 != NULL)
			  {
			    push_msg (MSGCAT_SYNTAX_DUPLICATED_REF_RULE);
			    csql_yyerror_explicit (@2.first_line, @2.first_column);
			  }

			ctn.c3 = $5;
			$$ = ctn;

		DBG_PRINT}}
	| ON_ DELETE_ CASCADE
		{{

			container_3 ctn;
			SET_CONTAINER_3 (ctn, FROM_NUMBER (PT_RULE_CASCADE), NULL, NULL);
			$$ = ctn;

		DBG_PRINT}}
	| ON_ DELETE_ NO ACTION
		{{

			container_3 ctn;
			SET_CONTAINER_3 (ctn, FROM_NUMBER (PT_RULE_NO_ACTION), NULL, NULL);
			$$ = ctn;

		DBG_PRINT}}
	| ON_ DELETE_ RESTRICT
		{{

			container_3 ctn;
			SET_CONTAINER_3 (ctn, FROM_NUMBER (PT_RULE_RESTRICT), NULL, NULL);
			$$ = ctn;

		DBG_PRINT}}
	| ON_ DELETE_ SET Null
		{{

			container_3 ctn;
			SET_CONTAINER_3 (ctn, FROM_NUMBER (PT_RULE_SET_NULL), NULL, NULL);
			$$ = ctn;

		DBG_PRINT}}
	| ON_ UPDATE NO ACTION
		{{

			container_3 ctn;
			SET_CONTAINER_3 (ctn, NULL, FROM_NUMBER (PT_RULE_NO_ACTION), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| ON_ UPDATE RESTRICT
		{{

			container_3 ctn;
			SET_CONTAINER_3 (ctn, NULL, FROM_NUMBER (PT_RULE_RESTRICT), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| ON_ UPDATE SET Null
		{{

			container_3 ctn;
			SET_CONTAINER_3 (ctn, NULL, FROM_NUMBER (PT_RULE_SET_NULL), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| ON_ CACHE OBJECT identifier
		{{

			container_3 ctn;
			SET_CONTAINER_3 (ctn, NULL, NULL, $4);
			$$ = ctn;

		DBG_PRINT}}
	;


check_constraint
	: CHECK '(' search_condition ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_CONSTRAINT);

			if (node)
			  {
			    node->info.constraint.type = PT_CONSTRAIN_CHECK;
			    node->info.constraint.un.check.expr = $3;
			  }

			$$ = node;

		DBG_PRINT}}
	;


/* bool_deferrable, deferrable value, bool_initially_deferred, initially_deferred value */
constraint_attr
	: NOT DEFERRABLE
		{{

			container_4 ctn;
			ctn.c1 = FROM_NUMBER (1);
			ctn.c2 = FROM_NUMBER (0);
			ctn.c3 = FROM_NUMBER (0);
			ctn.c4 = FROM_NUMBER (0);
			$$ = ctn;

		DBG_PRINT}}
	| DEFERRABLE
		{{

			container_4 ctn;
			ctn.c1 = FROM_NUMBER (1);
			ctn.c2 = FROM_NUMBER (1);
			ctn.c3 = FROM_NUMBER (0);
			ctn.c4 = FROM_NUMBER (0);
			$$ = ctn;

		DBG_PRINT}}
	| INITIALLY DEFERRED
		{{

			container_4 ctn;
			ctn.c1 = FROM_NUMBER (0);
			ctn.c2 = FROM_NUMBER (0);
			ctn.c3 = FROM_NUMBER (1);
			ctn.c4 = FROM_NUMBER (1);
			$$ = ctn;

		DBG_PRINT}}
	| INITIALLY IMMEDIATE
		{{

			container_4 ctn;
			ctn.c1 = FROM_NUMBER (0);
			ctn.c2 = FROM_NUMBER (0);
			ctn.c3 = FROM_NUMBER (1);
			ctn.c4 = FROM_NUMBER (0);
			$$ = ctn;

		DBG_PRINT}}
	;

method_def_list
	: method_def_list ',' method_def
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| method_def
		{{

			$$ = $1;

		DBG_PRINT}}
	;

method_def
	: opt_class
	  identifier
	  opt_method_def_arg_list
	  opt_data_type
	  opt_function_identifier
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_METHOD_DEF);
			PT_MISC_TYPE t = PT_NORMAL;
			if ($1)
			  t = PT_META_ATTR;

			if (node)
			  {
			    node->info.method_def.method_name = $2;
			    node->info.method_def.mthd_type = t;
			    node->info.method_def.method_args_list = $3;
			    node->type_enum = TO_NUMBER (CONTAINER_AT_0 ($4));
			    node->data_type = CONTAINER_AT_1 ($4);
			    node->info.method_def.function_name = $5;
			  }
			$$ = node;

		DBG_PRINT}}
	;

opt_method_def_arg_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| '(' arg_type_list ')'
		{{

			$$ = $2;

		DBG_PRINT}}
	| '(' ')'
		{{

			$$ = NULL;

		DBG_PRINT}}
	;

arg_type_list
	: arg_type_list ',' inout_data_type
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| inout_data_type
		{{

			$$ = $1;

		DBG_PRINT}}
	;

inout_data_type
	: opt_in_out data_type
		{{

			PT_NODE *at = parser_new_node (this_parser, PT_DATA_TYPE);

			if (at)
			  {
			    at->type_enum = TO_NUMBER (CONTAINER_AT_0 ($2));
			    at->data_type = CONTAINER_AT_1 ($2);
			    at->info.data_type.inout = $1;
			  }

			$$ = at;

		DBG_PRINT}}
	;

opt_data_type
	: /* empty */
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_NONE), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| data_type
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_function_identifier
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| FUNCTION identifier
		{{

			$$ = $2;

		DBG_PRINT}}
	;

method_file_list
	: method_file_list ',' file_path_name
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| file_path_name
		{{

			$$ = $1;

		DBG_PRINT}}
	;

file_path_name
	: char_string_literal
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_FILE_PATH);
			if (node)
			  node->info.file_path.string = $1;
			$$ = node;

		DBG_PRINT}}
	;

opt_class_attr_def_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| CLASS
	  ATTRIBUTE
		{ parser_attr_type = PT_META_ATTR; }
	 '(' attr_def_list ')'
		{ parser_attr_type = PT_NORMAL; }
		{{

			$$ = $5;

		DBG_PRINT}}
	;

class_or_normal_attr_def_list
	: class_or_normal_attr_def_list  ',' class_or_normal_attr_def
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| class_or_normal_attr_def
		{{

			$$ = $1;

		DBG_PRINT}}
	;

class_or_normal_attr_def
	: CLASS { parser_attr_type = PT_META_ATTR; } attr_def { parser_attr_type = PT_NORMAL; }
		{{

			$$ = $3;

		DBG_PRINT}}
	| attr_def
		{{

			$$ = $1;

		DBG_PRINT}}
	;

view_attr_def_list
	: view_attr_def_list ',' view_attr_def
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| view_attr_def
		{{

			$$ = $1;

		DBG_PRINT}}
	;

view_attr_def
	: attr_def
		{{

			$$ = $1;

		DBG_PRINT}}
	| identifier
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_ATTR_DEF);

			if (node)
			  {
			    node->data_type = NULL;
			    node->info.attr_def.attr_name = $1;
			    node->info.attr_def.attr_type = PT_NORMAL;
			  }

			$$ = node;

		DBG_PRINT}}
	;

attr_def_list_with_commas
	: attr_def_list_with_commas ','  attr_def
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| attr_def ','  attr_def
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	;

attr_def_list
	: attr_def_list ','  attr_def
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| attr_def
		{{

			$$ = $1;

		DBG_PRINT}}
	;

attr_def
	: attr_constraint_def
		{{

			$$ = $1;

		DBG_PRINT}}
	| attr_index_def
		{{

			$$ = $1;

		DBG_PRINT}}
	| attr_def_one
		{{

			$$ = $1;

		DBG_PRINT}}
	;

attr_constraint_def
	: opt_constraint_opt_id
	  of_unique_foreign_check
	  opt_constraint_attr_list
		{{

			PT_NODE *name = $1;
			PT_NODE *constraint = $2;

			/* If both the constraint name and the index name are
			   given we ignore the constraint name because that is
			   what MySQL does for UNIQUE constraints. */
			if (constraint->info.constraint.name == NULL)
			  {
			    constraint->info.constraint.name = name;
			  }

			if (TO_NUMBER (CONTAINER_AT_0 ($3)))
			  {
			    constraint->info.constraint.deferrable = (short)TO_NUMBER (CONTAINER_AT_1 ($3));
			  }

			if (TO_NUMBER (CONTAINER_AT_2 ($3)))
			  {
			    constraint->info.constraint.initially_deferred =
			      (short)TO_NUMBER (CONTAINER_AT_3 ($3));
			  }

			$$ = constraint;

		DBG_PRINT}}

attr_index_def
	: index_or_key
	  opt_identifier
	  index_column_name_list
		{{
			PT_NODE* node = parser_new_node(this_parser, PT_CREATE_INDEX);

			node->info.index.index_name = $2;
			node->info.index.indexed_class = NULL;
			node->info.index.column_names = $3;

			$$ = node;
		DBG_PRINT}}
	| index_or_key
	  opt_identifier				/* 2 */
	  '(' index_column_name				/* 3, 4 */
	  '(' opt_uint_or_host_input ')' 		/* 5, 6, 7 */
	  opt_asc_or_desc ')'				/* 8, 9 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_CREATE_INDEX);

			node->info.index.index_name = $2;
			node->info.index.indexed_class = NULL;
			node->info.index.column_names = $4;
			node->info.index.prefix_length = $6;

			if ($4 && $8)
			  {
			    $4->info.sort_spec.asc_or_desc = $8;
			  }

			$$ = node;

		DBG_PRINT}}
	;

attr_def_one
	: identifier
	  data_type
		{{

			PT_NODE *dt;
			PT_TYPE_ENUM typ;
			PT_NODE *node = parser_new_node (this_parser, PT_ATTR_DEF);

			if (node)
			  {
			    node->type_enum = typ = TO_NUMBER (CONTAINER_AT_0 ($2));
			    node->data_type = dt = CONTAINER_AT_1 ($2);
			    node->info.attr_def.attr_name = $1;
			    if (typ == PT_TYPE_CHAR && dt)
			      node->info.attr_def.size_constraint = dt->info.data_type.precision;
			    if (typ == PT_TYPE_OBJECT && dt && dt->type_enum == PT_TYPE_VARCHAR)
			      {
				node->type_enum = dt->type_enum;
				PT_NAME_INFO_SET_FLAG (node->info.attr_def.attr_name,
						       PT_NAME_INFO_EXTERNAL);
			      }
			  }

			parser_save_attr_def_one (node);

		DBG_PRINT}}
	  constraint_list
	  opt_attr_ordering_info								%dprec 2
		{{

			PT_NODE *node = parser_get_attr_def_one ();
			if (node != NULL && node->info.attr_def.attr_type != PT_SHARED)
			  {
			    node->info.attr_def.attr_type = parser_attr_type;
			  }
			if (node != NULL)
			  {
			    node->info.attr_def.ordering_info = $5;
			  }

			$$ = node;

		DBG_PRINT}}
	| identifier
	  data_type
	  opt_attr_ordering_info 									%dprec 1
		{{

			PT_NODE *dt;
			PT_TYPE_ENUM typ;
			PT_NODE *node = parser_new_node (this_parser, PT_ATTR_DEF);

			if (node)
			  {
			    node->type_enum = typ = TO_NUMBER (CONTAINER_AT_0 ($2));
			    node->data_type = dt = CONTAINER_AT_1 ($2);
			    node->info.attr_def.attr_name = $1;
			    if (typ == PT_TYPE_CHAR && dt)
			      node->info.attr_def.size_constraint = dt->info.data_type.precision;
			    if (typ == PT_TYPE_OBJECT && dt && dt->type_enum == PT_TYPE_VARCHAR)
			      {
				node->type_enum = dt->type_enum;
				PT_NAME_INFO_SET_FLAG (node->info.attr_def.attr_name,
						       PT_NAME_INFO_EXTERNAL);
			      }
			    if (node->info.attr_def.attr_type != PT_SHARED)
			      {
			        node->info.attr_def.attr_type = parser_attr_type;
			      }
			    node->info.attr_def.ordering_info = $3;
			  }

			$$ = node;

		DBG_PRINT}}
	;

opt_attr_ordering_info
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| FIRST
		{{

			PT_NODE *ord = parser_new_node (this_parser, PT_ATTR_ORDERING);
			if (ord)
			  {
			    ord->info.attr_ordering.first = true;
			    if (!allow_attribute_ordering)
			      {
				PT_ERRORmf(this_parser, ord,
					   MSGCAT_SET_PARSER_SEMANTIC,
					   MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "FIRST");
			      }
			  }

			$$ = ord;

		DBG_PRINT}}
	| AFTER identifier
		{{

			PT_NODE *ord = parser_new_node (this_parser, PT_ATTR_ORDERING);
			if (ord)
			  {
			    ord->info.attr_ordering.after = $2;
			    if (!allow_attribute_ordering)
			      {
				PT_ERRORmf(this_parser, ord,
					   MSGCAT_SET_PARSER_SEMANTIC,
					   MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "AFTER column");
			      }
			  }

			$$ = ord;

		DBG_PRINT}}
	;

constraint_list
	: constraint_list column_constraint_def
		{{
			unsigned char mask = $1;
			unsigned char new_bit = $2;
			unsigned char merged = mask | new_bit;

			/* Check the constraints according to the following rules:
			 *   1. A constraint should be specified once.
			 *   2. Only one of SHARED, DEFAULT or AI can be specified.
			 *   3. SHARED constraint cannot be defined with UNIQUE or PK constraint.
			 */
			if (((mask & new_bit) ^ new_bit) == 0)
			  {
			    PT_ERROR (this_parser, pt_top(this_parser),
				      "Multiple definitions exist for a constraint");
			  }
			else if ((new_bit & COLUMN_CONSTRAINT_SHARED_DEFAULT_AI)
				  && ((merged & COLUMN_CONSTRAINT_SHARED_DEFAULT_AI)
				       ^ (new_bit & COLUMN_CONSTRAINT_SHARED_DEFAULT_AI)) != 0)
			  {
			    PT_ERROR (this_parser, pt_top(this_parser),
				      "SHARED, DEFAULT and AUTO_INCREMENT cannot be defined with each other");
			  }
			else if ((merged & COLUMN_CONSTRAINT_SHARED)
			          && ((merged & COLUMN_CONSTRAINT_UNIQUE)
				       || (merged & COLUMN_CONSTRAINT_PRIMARY_KEY)))
			  {
			    PT_ERROR (this_parser, pt_top(this_parser),
				      "SHARED cannot be defined with PRIMARY KEY or UNIQUE constraint");
			  }

			$$ = merged;
		}}
	| column_constraint_def
		{{
			$$ = $1;
		}}
	;

column_constraint_def
	: column_unique_constraint_def
		{{
			$$ = COLUMN_CONSTRAINT_UNIQUE;
		}}
	| column_primary_constraint_def
		{{
			$$ = COLUMN_CONSTRAINT_PRIMARY_KEY;
		}}
	| column_null_constraint_def
		{{
			$$ = COLUMN_CONSTRAINT_NULL;
		}}
	| column_other_constraint_def
		{{
			$$ = COLUMN_CONSTRAINT_OTHERS;
		}}
	| column_shared_constraint_def
		{{
			$$ = COLUMN_CONSTRAINT_SHARED;
		}}
	| column_default_constraint_def
		{{
			$$ = COLUMN_CONSTRAINT_DEFAULT;
		}}
	| column_ai_constraint_def
		{{
			$$ = COLUMN_CONSTRAINT_AUTO_INCREMENT;
		}}
	;

column_unique_constraint_def
	: opt_constraint_id UNIQUE opt_key opt_constraint_attr_list
		{{

			PT_NODE *node = parser_get_attr_def_one ();
			PT_NODE *constrant_name = $1;
			PT_NODE *constraint = parser_new_node (this_parser, PT_CONSTRAINT);

			if (constraint)
			  {
			    constraint->info.constraint.type = PT_CONSTRAIN_UNIQUE;
			    constraint->info.constraint.un.unique.attrs
			      = parser_copy_tree (this_parser, node->info.attr_def.attr_name);

			    if (node->info.attr_def.attr_type == PT_SHARED)
			      constraint->info.constraint.un.unique.attrs->info.name.meta_class
				= PT_SHARED;

			    else
			      constraint->info.constraint.un.unique.attrs->info.name.meta_class
				= parser_attr_type;

			    constraint->info.constraint.name = $1;

			    if (TO_NUMBER (CONTAINER_AT_0 ($4)))
			      {
				constraint->info.constraint.deferrable =
				  (short)TO_NUMBER (CONTAINER_AT_1 ($4));
			      }

			    if (TO_NUMBER (CONTAINER_AT_2 ($4)))
			      {
				constraint->info.constraint.initially_deferred =
				  (short)TO_NUMBER (CONTAINER_AT_3 ($4));
			      }
			  }

			parser_make_link (node, constraint);

		DBG_PRINT}}
	;

column_primary_constraint_def
	: opt_constraint_id PRIMARY KEY opt_constraint_attr_list
		{{

			PT_NODE *node = parser_get_attr_def_one ();
			PT_NODE *constrant_name = $1;
			PT_NODE *constraint = parser_new_node (this_parser, PT_CONSTRAINT);

			if (constraint)
			  {
			    constraint->info.constraint.type = PT_CONSTRAIN_PRIMARY_KEY;
			    constraint->info.constraint.un.unique.attrs
			      = parser_copy_tree (this_parser, node->info.attr_def.attr_name);

			    constraint->info.constraint.name = $1;

			    if (TO_NUMBER (CONTAINER_AT_0 ($4)))
			      {
				constraint->info.constraint.deferrable =
				  (short)TO_NUMBER (CONTAINER_AT_1 ($4));
			      }

			    if (TO_NUMBER (CONTAINER_AT_2 ($4)))
			      {
				constraint->info.constraint.initially_deferred =
				  (short)TO_NUMBER (CONTAINER_AT_3 ($4));
			      }
			  }

			parser_make_link (node, constraint);

		DBG_PRINT}}
	;

column_null_constraint_def
	: opt_constraint_id Null opt_constraint_attr_list
		{{

			PT_NODE *node = parser_get_attr_def_one ();
			PT_NODE *constrant_name = $1;
			PT_NODE *constraint = parser_new_node (this_parser, PT_CONSTRAINT);

						/* to support null in ODBC-DDL, ignore it */
			if (constraint)
			  {
			    constraint->info.constraint.type = PT_CONSTRAIN_NULL;
			    constraint->info.constraint.name = $1;

			    if (TO_NUMBER (CONTAINER_AT_0 ($3)))
			      {
				constraint->info.constraint.deferrable =
				  (short)TO_NUMBER (CONTAINER_AT_1 ($3));
			      }

			    if (TO_NUMBER (CONTAINER_AT_2 ($3)))
			      {
				constraint->info.constraint.initially_deferred =
				  (short)TO_NUMBER (CONTAINER_AT_3 ($3));
			      }
			  }

			parser_make_link (node, constraint);

		DBG_PRINT}}
	| opt_constraint_id NOT Null opt_constraint_attr_list
		{{

			PT_NODE *node = parser_get_attr_def_one ();
			PT_NODE *constrant_name = $1;
			PT_NODE *constraint = parser_new_node (this_parser, PT_CONSTRAINT);


			if (constraint)
			  {
			    constraint->info.constraint.type = PT_CONSTRAIN_NOT_NULL;
			    constraint->info.constraint.un.not_null.attr
			      = parser_copy_tree (this_parser, node->info.attr_def.attr_name);
			    /*
			     * This should probably be deferred until semantic
			     * analysis time; leave it this way for now.
			     */
			    node->info.attr_def.constrain_not_null = 1;

			    constraint->info.constraint.name = $1;

			    if (TO_NUMBER (CONTAINER_AT_0 ($4)))
			      {
				constraint->info.constraint.deferrable =
				  (short)TO_NUMBER (CONTAINER_AT_1 ($4));
			      }

			    if (TO_NUMBER (CONTAINER_AT_2 ($4)))
			      {
				constraint->info.constraint.initially_deferred =
				  (short)TO_NUMBER (CONTAINER_AT_3 ($4));
			      }
			  }

			parser_make_link (node, constraint);

		DBG_PRINT}}
	;

column_other_constraint_def
	: opt_constraint_id CHECK '(' search_condition ')' opt_constraint_attr_list
		{{

			PT_NODE *node = parser_get_attr_def_one ();
			PT_NODE *constrant_name = $1;
			PT_NODE *constraint = parser_new_node (this_parser, PT_CONSTRAINT);

			if (constraint)
			  {
			    constraint->info.constraint.type = PT_CONSTRAIN_CHECK;
			    constraint->info.constraint.un.check.expr = $4;

			    constraint->info.constraint.name = $1;

			    if (TO_NUMBER (CONTAINER_AT_0 ($6)))
			      {
				constraint->info.constraint.deferrable =
				  (short)TO_NUMBER (CONTAINER_AT_1 ($6));
			      }

			    if (TO_NUMBER (CONTAINER_AT_2 ($6)))
			      {
				constraint->info.constraint.initially_deferred =
				  (short)TO_NUMBER (CONTAINER_AT_3 ($6));
			      }
			  }

			parser_make_link (node, constraint);

		DBG_PRINT}}
	| opt_constraint_id			/* 1 */
	  FOREIGN				/* 2 */
	  KEY					/* 3 */
	  REFERENCES				/* 4 */
	  class_name				/* 5 */
	  opt_paren_attr_list			/* 6 */
	  opt_ref_rule_list			/* 7 */
	  opt_constraint_attr_list		/* 8 */
		{{

			PT_NODE *node = parser_get_attr_def_one ();
			PT_NODE *constrant_name = $1;
			PT_NODE *constraint = parser_new_node (this_parser, PT_CONSTRAINT);

			if (constraint)
			  {
			    constraint->info.constraint.un.foreign_key.referenced_attrs = $6;
			    constraint->info.constraint.un.foreign_key.match_type = PT_MATCH_REGULAR;
			    constraint->info.constraint.un.foreign_key.delete_action = TO_NUMBER (CONTAINER_AT_0 ($7));	/* delete_action */
			    constraint->info.constraint.un.foreign_key.update_action = TO_NUMBER (CONTAINER_AT_1 ($7));	/* update_action */
			    constraint->info.constraint.un.foreign_key.cache_attr = CONTAINER_AT_2 ($7);	/* cache_attr */
			    constraint->info.constraint.un.foreign_key.referenced_class = $5;
			  }

			if (constraint)
			  {
			    constraint->info.constraint.type = PT_CONSTRAIN_FOREIGN_KEY;
			    constraint->info.constraint.un.foreign_key.attrs
			      = parser_copy_tree (this_parser, node->info.attr_def.attr_name);

			    constraint->info.constraint.name = $1;

			    if (TO_NUMBER (CONTAINER_AT_0 ($8)))
			      {
				constraint->info.constraint.deferrable =
				  (short)TO_NUMBER (CONTAINER_AT_1 ($8));
			      }

			    if (TO_NUMBER (CONTAINER_AT_2 ($8)))
			      {
				constraint->info.constraint.initially_deferred =
				  (short)TO_NUMBER (CONTAINER_AT_3 ($8));
			      }
			  }

			parser_make_link (node, constraint);

		DBG_PRINT}}
	;

index_or_key
	: INDEX
	| KEY
	;

opt_of_index_key
	: /* empty */
	| INDEX
	| KEY
	;

opt_key
	: /* empty */
	| KEY
	;

column_ai_constraint_def
	: AUTO_INCREMENT '(' integer_text ',' integer_text ')'
		{{

			PT_NODE *node = parser_get_attr_def_one ();
			PT_NODE *start_val = parser_new_node (this_parser, PT_VALUE);
			PT_NODE *increment_val = parser_new_node (this_parser, PT_VALUE);
			PT_NODE *ai_node;

			if (start_val)
			  {
			    start_val->info.value.text = $3;
			    start_val->type_enum = PT_TYPE_NUMERIC;
			  }

			if (increment_val)
			  {
			    increment_val->info.value.text = $5;
			    increment_val->type_enum = PT_TYPE_NUMERIC;
			  }

			ai_node = parser_new_node (this_parser, PT_AUTO_INCREMENT);
			ai_node->info.auto_increment.start_val = start_val;
			ai_node->info.auto_increment.increment_val = increment_val;
			node->info.attr_def.auto_increment = ai_node;

			if (parser_attr_type == PT_META_ATTR)
			  {
			    PT_ERRORm (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
				       MSGCAT_SEMANTIC_CLASS_ATT_CANT_BE_AUTOINC);
			  }

		DBG_PRINT}}
	| AUTO_INCREMENT
		{{

			PT_NODE *node = parser_get_attr_def_one ();

			PT_NODE *ai_node = parser_new_node (this_parser, PT_AUTO_INCREMENT);
			ai_node->info.auto_increment.start_val = NULL;
			ai_node->info.auto_increment.increment_val = NULL;
			node->info.attr_def.auto_increment = ai_node;

			if (parser_attr_type == PT_META_ATTR)
			  {
			    PT_ERRORm (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
				       MSGCAT_SEMANTIC_CLASS_ATT_CANT_BE_AUTOINC);
			  }

		DBG_PRINT}}
	;

column_shared_constraint_def
	: SHARED expression_
		{{
			PT_NODE *attr_node;
			PT_NODE *node = parser_new_node (this_parser, PT_DATA_DEFAULT);

			if (node)
			  {
			    node->info.data_default.default_value = $2;
			    node->info.data_default.shared = PT_SHARED;
			  }

			attr_node = parser_get_attr_def_one ();
			attr_node->info.attr_def.data_default = node;
			attr_node->info.attr_def.attr_type = PT_SHARED;

		DBG_PRINT}}
	;

column_default_constraint_def
	: DEFAULT expression_
		{{
			PT_NODE *attr_node;
			PT_NODE *node = parser_new_node (this_parser, PT_DATA_DEFAULT);

			if (node)
			  {
			    node->info.data_default.default_value = $2;
			    node->info.data_default.shared = PT_DEFAULT;
			  }

			attr_node = parser_get_attr_def_one ();
			attr_node->info.attr_def.data_default = node;

		DBG_PRINT}}
	;


transaction_mode_list
	: transaction_mode_list ',' transaction_mode			%dprec 1
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| transaction_mode						%dprec 2
		{{

			$$ = $1;

		DBG_PRINT}}
	;

transaction_mode
	: ISOLATION LEVEL isolation_level_spec ',' isolation_level_spec		%dprec 1
		{{

			PT_NODE *tm = parser_new_node (this_parser, PT_ISOLATION_LVL);
			PT_NODE *is = parser_new_node (this_parser, PT_ISOLATION_LVL);
			int async_ws_or_error;

			if (tm && is)
			  {
			    async_ws_or_error =  TO_NUMBER (CONTAINER_AT_3 ($3));
			    if (async_ws_or_error < 0)
			      {
				PT_ERRORm(this_parser, tm, MSGCAT_SET_PARSER_SYNTAX,
					  MSGCAT_SYNTAX_READ_UNCOMMIT);
				async_ws_or_error = 0;
			      }
			    tm->info.isolation_lvl.level = CONTAINER_AT_0 ($3);
			    tm->info.isolation_lvl.schema = TO_NUMBER (CONTAINER_AT_1 ($3));
			    tm->info.isolation_lvl.instances = TO_NUMBER (CONTAINER_AT_2 ($3));
			    tm->info.isolation_lvl.async_ws = async_ws_or_error;


			    async_ws_or_error =  TO_NUMBER (CONTAINER_AT_3 ($5));
			    if (async_ws_or_error < 0)
			      {
				PT_ERRORm(this_parser, is, MSGCAT_SET_PARSER_SYNTAX,
					  MSGCAT_SYNTAX_READ_UNCOMMIT);
				async_ws_or_error = 0;
			      }
			    is->info.isolation_lvl.level = CONTAINER_AT_0 ($5);
			    is->info.isolation_lvl.schema = TO_NUMBER (CONTAINER_AT_1 ($5));
			    is->info.isolation_lvl.instances = TO_NUMBER (CONTAINER_AT_2 ($5));
			    is->info.isolation_lvl.async_ws = async_ws_or_error;

			    if (tm->info.isolation_lvl.async_ws)
			      {
				if (is->info.isolation_lvl.async_ws)
				  {
				    /* async_ws, async_ws */
				  }
				else
				  {
				    /* async_ws, iso_lvl */
				    tm->info.isolation_lvl.schema = is->info.isolation_lvl.schema;
				    tm->info.isolation_lvl.instances =
				      is->info.isolation_lvl.instances;
				    tm->info.isolation_lvl.level = is->info.isolation_lvl.level;
				  }
			      }
			    else
			      {
				if (is->info.isolation_lvl.async_ws)
				  {
				    /* iso_lvl, async_ws */
				    tm->info.isolation_lvl.async_ws = 1;
				  }
				else
				  {
				    /* iso_lvl, iso_lvl */
				    if (tm->info.isolation_lvl.level != NULL
					|| is->info.isolation_lvl.level != NULL)
				      PT_ERRORm (this_parser, tm, MSGCAT_SET_PARSER_SEMANTIC,
						 MSGCAT_SEMANTIC_GT_1_ISOLATION_LVL);
				    else if (tm->info.isolation_lvl.schema !=
					     is->info.isolation_lvl.schema
					     || tm->info.isolation_lvl.instances !=
					     is->info.isolation_lvl.instances)
				      PT_ERRORm (this_parser, tm, MSGCAT_SET_PARSER_SEMANTIC,
						 MSGCAT_SEMANTIC_GT_1_ISOLATION_LVL);
				  }
			      }

			    is->info.isolation_lvl.level = NULL;
			    parser_free_node (this_parser, is);
			  }

			$$ = tm;

		DBG_PRINT}}
	| ISOLATION LEVEL isolation_level_spec			%dprec 2
		{{

			PT_NODE *tm = parser_new_node (this_parser, PT_ISOLATION_LVL);
			int async_ws_or_error =  TO_NUMBER (CONTAINER_AT_3 ($3));

			if (async_ws_or_error < 0)
			  {
			    PT_ERRORm(this_parser, tm, MSGCAT_SET_PARSER_SYNTAX,
				      MSGCAT_SYNTAX_READ_UNCOMMIT);
			    async_ws_or_error = 0;
			  }

			if (tm)
			  {
			    tm->info.isolation_lvl.level = CONTAINER_AT_0 ($3);
			    tm->info.isolation_lvl.schema = TO_NUMBER (CONTAINER_AT_1 ($3));
			    tm->info.isolation_lvl.instances = TO_NUMBER (CONTAINER_AT_2 ($3));
			    tm->info.isolation_lvl.async_ws = async_ws_or_error;
			  }

			$$ = tm;

		DBG_PRINT}}
	| LOCK_ TIMEOUT timeout_spec
		{{

			PT_NODE *tm = parser_new_node (this_parser, PT_TIMEOUT);

			if (tm)
			  {
			    tm->info.timeout.val = $3;
			  }

			$$ = tm;

		DBG_PRINT}}
	;


/* container order : level, schema, instances, async_ws */
isolation_level_spec
	: expression_
		{{

			container_4 ctn;
			SET_CONTAINER_4 (ctn, $1, FROM_NUMBER (PT_NO_ISOLATION_LEVEL),
					 FROM_NUMBER (PT_NO_ISOLATION_LEVEL), FROM_NUMBER (0));
			$$ = ctn;

		DBG_PRINT}}
	| ASYNC WORKSPACE
		{{

			container_4 ctn;
			SET_CONTAINER_4 (ctn, NULL, FROM_NUMBER (PT_NO_ISOLATION_LEVEL),
					 FROM_NUMBER (PT_NO_ISOLATION_LEVEL), FROM_NUMBER (1));
			$$ = ctn;

		DBG_PRINT}}
	| SERIALIZABLE
		{{

			container_4 ctn;
			SET_CONTAINER_4 (ctn, NULL, FROM_NUMBER (PT_SERIALIZABLE),
					 FROM_NUMBER (PT_SERIALIZABLE), FROM_NUMBER (0));
			$$ = ctn;

		DBG_PRINT}}
	| CURSOR STABILITY
		{{

			container_4 ctn;
			SET_CONTAINER_4 (ctn, NULL, FROM_NUMBER (PT_NO_ISOLATION_LEVEL),
					 FROM_NUMBER (PT_READ_COMMITTED), FROM_NUMBER (0));
			$$ = ctn;

		DBG_PRINT}}
	| isolation_level_name								%dprec 1
		{{

			container_4 ctn;
			PT_MISC_TYPE level = 0;
			if ($1 != PT_REPEATABLE_READ)
			  level = $1;

			SET_CONTAINER_4 (ctn, NULL, FROM_NUMBER (PT_NO_ISOLATION_LEVEL),
					 FROM_NUMBER (level), FROM_NUMBER (0));
			$$ = ctn;

		DBG_PRINT}}
	| isolation_level_name of_schema_class 						%dprec 1
		{{

			container_4 ctn;
			PT_MISC_TYPE schema = 0;
			PT_MISC_TYPE level = 0;
			int error = 0;

			schema = $1;

			if ($1 == PT_READ_UNCOMMITTED)
			  {
			    schema = PT_READ_COMMITTED;
			    error = -1;
			  }

			level = PT_NO_ISOLATION_LEVEL;

			SET_CONTAINER_4 (ctn, NULL, FROM_NUMBER (schema), FROM_NUMBER (level),
					 FROM_NUMBER (error));
			$$ = ctn;

		DBG_PRINT}}
	| isolation_level_name INSTANCES						%dprec 1
		{{

			container_4 ctn;
			PT_MISC_TYPE schema = 0;
			PT_MISC_TYPE level = 0;

			schema = PT_NO_ISOLATION_LEVEL;
			level = $1;

			SET_CONTAINER_4 (ctn, NULL, FROM_NUMBER (schema), FROM_NUMBER (level),
					 FROM_NUMBER (0));
			$$ = ctn;

		DBG_PRINT}}
	| isolation_level_name of_schema_class ',' isolation_level_name INSTANCES	%dprec 10
		{{

			container_4 ctn;
			PT_MISC_TYPE schema = 0;
			PT_MISC_TYPE level = 0;
			int error = 0;

			level = $4;
			schema = $1;

			if ($1 == PT_READ_UNCOMMITTED)
			  {
			    schema = PT_READ_COMMITTED;
			    error = -1;
			  }

			SET_CONTAINER_4 (ctn, NULL, FROM_NUMBER (schema), FROM_NUMBER (level),
					 FROM_NUMBER (error));
			$$ = ctn;

		DBG_PRINT}}
	| isolation_level_name INSTANCES ',' isolation_level_name of_schema_class	%dprec 10
		{{
			container_4 ctn;
			PT_MISC_TYPE schema = 0;
			PT_MISC_TYPE level = 0;
			int error = 0;

			level = $1;
			schema = $4;

			if ($4 == PT_READ_UNCOMMITTED)
			  {
			    schema = PT_READ_COMMITTED;
			    error = -1;
			  }

			SET_CONTAINER_4 (ctn, NULL, FROM_NUMBER (schema), FROM_NUMBER (level),
					 FROM_NUMBER (error));
			$$ = ctn;

		DBG_PRINT}}
	;

of_schema_class
	: SCHEMA
	| CLASS
	;

isolation_level_name
	: REPEATABLE READ
		{{

			$$ = PT_REPEATABLE_READ;

		DBG_PRINT}}
	| READ COMMITTED
		{{

			$$ = PT_READ_COMMITTED;

		DBG_PRINT}}
	| READ UNCOMMITTED
		{{

			$$ = PT_READ_UNCOMMITTED;

		DBG_PRINT}}
	;

timeout_spec
	: INFINITE_
		{{

			PT_NODE *val = parser_new_node (this_parser, PT_VALUE);

			if (val)
			  {
			    val->type_enum = PT_TYPE_INTEGER;
			    val->info.value.data_value.i = -1;
			  }

			$$ = val;

		DBG_PRINT}}
	| OFF_
		{{

			PT_NODE *val = parser_new_node (this_parser, PT_VALUE);

			if (val)
			  {
			    val->type_enum = PT_TYPE_INTEGER;
			    val->info.value.data_value.i = 0;
			  }

			$$ = val;

		DBG_PRINT}}
	| unsigned_integer
		{{

			$$ = $1;

		DBG_PRINT}}
	| unsigned_real
		{{

			$$ = $1;

		DBG_PRINT}}
	| param_
		{{

			$$ = $1;

		DBG_PRINT}}
	| host_param_input
		{{

			$$ = $1;

		DBG_PRINT}}
	;


transaction_stmt
	: COMMIT opt_work RETAIN LOCK_
		{{

			PT_NODE *comm = parser_new_node (this_parser, PT_COMMIT_WORK);

			if (comm)
			  {
			    comm->info.commit_work.retain_lock = 1;
			  }

			$$ = comm;

		DBG_PRINT}}
	| COMMIT opt_work
		{{

			PT_NODE *comm = parser_new_node (this_parser, PT_COMMIT_WORK);
			$$ = comm;

		DBG_PRINT}}
	| ROLLBACK opt_work TO opt_savepoint expression_
		{{

			PT_NODE *roll = parser_new_node (this_parser, PT_ROLLBACK_WORK);

			if (roll)
			  {
			    roll->info.rollback_work.save_name = $5;
			  }

			$$ = roll;

		DBG_PRINT}}
	| ROLLBACK opt_work
		{{

			PT_NODE *roll = parser_new_node (this_parser, PT_ROLLBACK_WORK);
			$$ = roll;

		DBG_PRINT}}
	| SAVEPOINT expression_
		{{

			PT_NODE *svpt = parser_new_node (this_parser, PT_SAVEPOINT);

			if (svpt)
			  {
			    svpt->info.savepoint.save_name = $2;
			  }

			$$ = svpt;

		DBG_PRINT}}
	;


opt_savepoint
	: /* empty */
	| SAVEPOINT
	;

opt_work
	: /* empty */
	| WORK
	;

opt_to
	: /* empty */
	| TO
	;

evaluate_stmt
	: EVALUATE expression_ into_clause_opt
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_EVALUATE);

			if (node)
			  {
			    node->info.evaluate.expression = $2;
			    node->info.evaluate.into_var = $3;
			  }

			$$ = node;

		DBG_PRINT}}
	;

prepare_stmt
	: PREPARE identifier FROM char_string
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_PREPARE_STATEMENT);

			if (node)
			  {
			    node->info.prepare.name = $2;
			    node->info.prepare.statement = $4;
			  }

			$$ = node;

		DBG_PRINT}}
	;

execute_stmt
	: EXECUTE identifier opt_using
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_EXECUTE_PREPARE);

			if (node)
			  {
			    node->info.prepare.name = $2;
			    node->info.prepare.using_list = $3;
			  }

			$$ = node;

		DBG_PRINT}}
	;

opt_using
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| USING { parser_save_and_set_hvar (0); } signed_literal_list { parser_restore_hvar (); }
		{{

			$$ = $3;

		DBG_PRINT}}
	;

opt_status
	: /* empty */
		{{

			$$ = PT_MISC_DUMMY;

		DBG_PRINT}}
	| trigger_status
		{{

			$$ = $1;

		DBG_PRINT}}
	;

trigger_status
	: STATUS ACTIVE
		{{

			$$ = PT_ACTIVE;

		DBG_PRINT}}
	| STATUS INACTIVE
		{{

			$$ = PT_INACTIVE;

		DBG_PRINT}}
	;

opt_priority
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| trigger_priority
		{{

			$$ = $1;

		DBG_PRINT}}
	;

trigger_priority
	: PRIORITY unsigned_real
		{{

			$$ = $2;

		DBG_PRINT}}
	;

opt_if_trigger_condition
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| IF trigger_condition
		{{

			$$ = $2;

		DBG_PRINT}}
	;

trigger_time
	: BEFORE
		{{

			$$ = PT_BEFORE;

		DBG_PRINT}}
	| AFTER
		{{

			$$ = PT_AFTER;

		DBG_PRINT}}
	| DEFERRED
		{{

			$$ = PT_DEFERRED;

		DBG_PRINT}}
	;

opt_trigger_action_time
	: /* empty */
		{{

			$$ = PT_MISC_DUMMY;

		DBG_PRINT}}
	| AFTER
		{{

			$$ = PT_AFTER;

		DBG_PRINT}}
	| DEFERRED
		{{

			$$ = PT_DEFERRED;

		DBG_PRINT}}
	;

event_spec
	: event_type
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_EVENT_SPEC);

			if (node)
			  {
			    node->info.event_spec.event_type = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	| event_type event_target
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_EVENT_SPEC);

			if (node)
			  {
			    node->info.event_spec.event_type = $1;
			    node->info.event_spec.event_target = $2;
			  }

			$$ = node;

		DBG_PRINT}}
	;

event_type
	: INSERT
		{{

			$$ = PT_EV_INSERT;

		DBG_PRINT}}
	| STATEMENT INSERT
		{{

			$$ = PT_EV_STMT_INSERT;

		DBG_PRINT}}
	| DELETE_
		{{

			$$ = PT_EV_DELETE;

		DBG_PRINT}}
	| STATEMENT DELETE_
		{{

			$$ = PT_EV_STMT_DELETE;

		DBG_PRINT}}
	| UPDATE
		{{

			$$ = PT_EV_UPDATE;

		DBG_PRINT}}
	| STATEMENT UPDATE
		{{

			$$ = PT_EV_STMT_UPDATE;

		DBG_PRINT}}
	| COMMIT
		{{

			$$ = PT_EV_COMMIT;

		DBG_PRINT}}
	| ROLLBACK
		{{

			$$ = PT_EV_ROLLBACK;

		DBG_PRINT}}
	;

event_target
	: ON_ identifier '(' identifier ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_EVENT_TARGET);

			if (node)
			  {
			    node->info.event_target.class_name = $2;
			    node->info.event_target.attribute = $4;
			  }

			$$ = node;

		DBG_PRINT}}
	| ON_ identifier
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_EVENT_TARGET);

			if (node)
			  {
			    node->info.event_target.class_name = $2;
			  }

			$$ = node;

		DBG_PRINT}}
	;

trigger_condition
	: search_condition
		{{

			$$ = $1;

		DBG_PRINT}}
	| call_stmt
		{{

			$$ = $1;

		DBG_PRINT}}
	;

trigger_action
	: REJECT_
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_TRIGGER_ACTION);

			if (node)
			  {
			    node->info.trigger_action.action_type = PT_REJECT;
			  }

			$$ = node;

		DBG_PRINT}}
	| INVALIDATE TRANSACTION
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_TRIGGER_ACTION);

			if (node)
			  {
			    node->info.trigger_action.action_type = PT_INVALIDATE_XACTION;
			  }

			$$ = node;

		DBG_PRINT}}
	| PRINT char_string_literal
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_TRIGGER_ACTION);

			if (node)
			  {
			    node->info.trigger_action.action_type = PT_PRINT;
			    node->info.trigger_action.string = $2;
			  }

			$$ = node;

		DBG_PRINT}}
	| evaluate_stmt
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_TRIGGER_ACTION);

			if (node)
			  {
			    node->info.trigger_action.action_type = PT_EXPRESSION;
			    node->info.trigger_action.expression = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	| insert_or_replace_stmt
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_TRIGGER_ACTION);

			if (node)
			  {
			    node->info.trigger_action.action_type = PT_EXPRESSION;
			    node->info.trigger_action.expression = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	| update_stmt
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_TRIGGER_ACTION);

			if (node)
			  {
			    node->info.trigger_action.action_type = PT_EXPRESSION;
			    node->info.trigger_action.expression = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	| delete_stmt
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_TRIGGER_ACTION);

			if (node)
			  {
			    node->info.trigger_action.action_type = PT_EXPRESSION;
			    node->info.trigger_action.expression = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	| call_stmt
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_TRIGGER_ACTION);

			if (node)
			  {
			    node->info.trigger_action.action_type = PT_EXPRESSION;
			    node->info.trigger_action.expression = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	;

trigger_spec_list
	: identifier_list
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_TRIGGER_SPEC_LIST);

			if (node)
			  {
			    node->info.trigger_spec_list.trigger_name_list = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	| ALL TRIGGERS
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_TRIGGER_SPEC_LIST);

			if (node)
			  {
			    node->info.trigger_spec_list.all_triggers = 1;
			  }

			$$ = node;

		DBG_PRINT}}
	;

trigger_status_or_priority
	: trigger_status
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER ($1), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| trigger_priority
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_MISC_DUMMY), $1);
			$$ = ctn;

		DBG_PRINT}}
	;

opt_maximum
	: /* empty */
	| MAXIMUM
	;

trace_spec
	: ON_
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);

			if (node)
			  {
			    node->info.value.data_value.i = -1;
			    node->type_enum = PT_TYPE_INTEGER;
			  }

			$$ = node;

		DBG_PRINT}}
	| OFF_
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);

			if (node)
			  {
			    node->info.value.data_value.i = 0;
			    node->type_enum = PT_TYPE_INTEGER;
			  }

			$$ = node;

		DBG_PRINT}}
	| unsigned_integer
		{{

			$$ = $1;

		DBG_PRINT}}
	| param_
		{{

			$$ = $1;

		DBG_PRINT}}
	| host_param_input
		{{

			$$ = $1;

		DBG_PRINT}}
	;

depth_spec
	: INFINITE_
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);

			if (node)
			  {
			    node->info.value.data_value.i = -1;
			    node->type_enum = PT_TYPE_INTEGER;
			  }

			$$ = node;

		DBG_PRINT}}
	| unsigned_integer
		{{

			$$ = $1;

		DBG_PRINT}}
	| param_
		{{

			$$ = $1;

		DBG_PRINT}}
	| host_param_input
		{{

			$$ = $1;

		DBG_PRINT}}
	;

serial_start
	: START_ WITH integer_text
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			if (node)
			  {
			    node->info.value.text = $3;
			    node->type_enum = PT_TYPE_NUMERIC;
			  }

			$$ = node;

		DBG_PRINT}}
	;

serial_increment
	: INCREMENT BY integer_text
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			if (node)
			  {
			    node->info.value.text = $3;
			    node->type_enum = PT_TYPE_NUMERIC;
			  }

			$$ = node;

		DBG_PRINT}}
	;


serial_min
	: MINVALUE integer_text
		{{

			container_2 ctn;
			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			if (node)
			  {
			    node->info.value.text = $2;
			    node->type_enum = PT_TYPE_NUMERIC;
			  }

			SET_CONTAINER_2 (ctn, node, FROM_NUMBER (0));
			$$ = ctn;

		DBG_PRINT}}
	| NOMINVALUE
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, NULL, FROM_NUMBER (1));
			$$ = ctn;

		DBG_PRINT}}
	;

serial_max
	: MAXVALUE integer_text
		{{

			container_2 ctn;
			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			if (node)
			  {
			    node->info.value.text = $2;
			    node->type_enum = PT_TYPE_NUMERIC;
			  }

			SET_CONTAINER_2 (ctn, node, FROM_NUMBER (0));
			$$ = ctn;

		DBG_PRINT}}
	| NOMAXVALUE
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, NULL, FROM_NUMBER (1));
			$$ = ctn;

		DBG_PRINT}}
	;

of_cycle_nocycle
	: CYCLE
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (1), FROM_NUMBER (0));
			$$ = ctn;

		DBG_PRINT}}
	| NOCYCLE
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (0), FROM_NUMBER (1));
			$$ = ctn;

		DBG_PRINT}}
	;

of_cached_num
	: CACHE unsigned_int32
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, $2, FROM_NUMBER (0));
			$$ = ctn;

		DBG_PRINT}}
	| NOCACHE
		{{
			container_2 ctn;
			SET_CONTAINER_2 (ctn, NULL, FROM_NUMBER (1));
			$$ = ctn;

		DBG_PRINT}}
	;

integer_text
	: opt_plus UNSIGNED_INTEGER
		{{

			$$ = $2;

		DBG_PRINT}}
	| '-' UNSIGNED_INTEGER
		{{

			$$ = pt_append_string (this_parser, (char *) "-", $2);

		DBG_PRINT}}
	;

uint_text
	: UNSIGNED_INTEGER
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_plus
	: /* empty */
	| '+'
	;

opt_of_data_type_cursor
	: /* empty */
		{{

			$$ = PT_TYPE_NONE;

		DBG_PRINT}}
	| data_type
		{{

			$$ = TO_NUMBER (CONTAINER_AT_0 ($1));

		DBG_PRINT}}
	| CURSOR
		{{

			$$ = PT_TYPE_RESULTSET;

		DBG_PRINT}}
	;

opt_of_is_as
	: /* empty */
	| IS
	| AS
	;

opt_sp_param_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| sp_param_list
		{{

			$$ = $1;

		DBG_PRINT}}
	;

sp_param_list
	: sp_param_list ',' sp_param_def
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| sp_param_def
		{{

			$$ = $1;

		DBG_PRINT}}
	;

sp_param_def
	: identifier opt_sp_in_out data_type
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SP_PARAMETERS);

			if (node)
			  {
			    node->type_enum = TO_NUMBER (CONTAINER_AT_0 ($3));
			    node->data_type = CONTAINER_AT_1 ($3);
			    node->info.sp_param.name = $1;
			    node->info.sp_param.mode = $2;
			  }

			$$ = node;

		DBG_PRINT}}
	| identifier opt_sp_in_out CURSOR
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SP_PARAMETERS);

			if (node)
			  {
			    node->type_enum = PT_TYPE_RESULTSET;
			    node->data_type = NULL;
			    node->info.sp_param.name = $1;
			    node->info.sp_param.mode = $2;
			  }

			$$ = node;

		DBG_PRINT}}
	;

opt_sp_in_out
	: opt_in_out
		{{

			$$ = $1;

		DBG_PRINT}}
	| IN_ OUT_
		{{

			$$ = PT_INPUTOUTPUT;

		DBG_PRINT}}
	;

esql_query_stmt
	: 	{ parser_select_level++; }
	  csql_query opt_for_update
		{{

			$2->info.query.for_update = $3;
			$$ = $2;
			parser_select_level--;

		DBG_PRINT}}
	;

opt_for_update
	: /* empty */
		{ $$ = NULL; }
	| For UPDATE OF sort_spec_list
		{ $$ = $4; }
	;

csql_query
	:
		{{

			parser_save_and_set_cannot_cache (false);
			parser_save_and_set_ic (0);
			parser_save_and_set_gc (0);
			parser_save_and_set_oc (0);
			parser_save_and_set_wjc (0);
			parser_save_and_set_sysc (0);
			parser_save_and_set_prc (0);
			parser_save_and_set_cbrc (0);
			parser_save_and_set_serc (1);
			parser_save_and_set_sqc (1);
			parser_save_and_set_pseudoc (1);

		DBG_PRINT}}
	  select_expression
		{{

			PT_NODE *node = $2;
			parser_push_orderby_node (node);

		DBG_PRINT}}
	  opt_orderby_clause
		{{

			PT_NODE *node = parser_pop_orderby_node ();

			if (node && parser_cannot_cache)
			  {
			    node->info.query.reexecute = 1;
			    node->info.query.do_cache = 0;
			    node->info.query.do_not_cache = 1;
			  }

			parser_restore_cannot_cache ();
			parser_restore_ic ();
			parser_restore_gc ();
			parser_restore_oc ();
			parser_restore_wjc ();
			parser_restore_sysc ();
			parser_restore_prc ();
			parser_restore_cbrc ();
			parser_restore_serc ();
			parser_restore_sqc ();
			parser_restore_pseudoc ();

			if (parser_subquery_check == 0)
			    PT_ERRORmf(this_parser, pt_top(this_parser),
				MSGCAT_SET_PARSER_SEMANTIC,
				MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "Subquery");

			if (node)
			  {
			    /* handle ORDER BY NULL */
			    PT_NODE *order = node->info.query.order_by;
			    if (order && order->info.sort_spec.expr
				&& order->info.sort_spec.expr->node_type == PT_VALUE
				&& order->info.sort_spec.expr->type_enum == PT_TYPE_NULL)
			      {
				if (!node->info.query.q.select.group_by)
				  {
				    PT_ERRORm (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
					       MSGCAT_SEMANTIC_ORDERBYNULL_REQUIRES_GROUPBY);
				  }
				else
				  {
				    parser_free_tree (this_parser, node->info.query.order_by);
				    node->info.query.order_by = NULL;
				  }
			      }
			  }

			parser_push_orderby_node (node);

		DBG_PRINT}}
	opt_select_limit_clause
		{{

			PT_NODE *node = parser_pop_orderby_node ();
			$$ = node;

		DBG_PRINT}}
	;

select_expression
	: select_expression table_op select_or_subquery
		{{

			PT_NODE *stmt = $2;

			if (stmt)
			  {
			    stmt->info.query.id = (UINTPTR) stmt;
			    stmt->info.query.q.union_.arg1 = $1;
			    stmt->info.query.q.union_.arg2 = $3;
			  }


			$$ = stmt;

		DBG_PRINT}}
	| select_or_subquery
		{{

			$$ = $1;

		DBG_PRINT}}
	;

table_op
	: Union all_distinct
		{{

			PT_MISC_TYPE isAll = $2;
			PT_NODE *node = parser_new_node (this_parser, PT_UNION);
			if (node)
			  {
			    if (isAll == PT_EMPTY)
			      isAll = PT_DISTINCT;
			    node->info.query.all_distinct = isAll;
			  }

			$$ = node;

		DBG_PRINT}}
	| DIFFERENCE_ all_distinct
		{{

			PT_MISC_TYPE isAll = $2;
			PT_NODE *node = parser_new_node (this_parser, PT_DIFFERENCE);
			if (node)
			  {
			    if (isAll == PT_EMPTY)
			      isAll = PT_DISTINCT;
			    node->info.query.all_distinct = isAll;
			  }

			$$ = node;

		DBG_PRINT}}
	| EXCEPT all_distinct
		{{

			PT_MISC_TYPE isAll = $2;
			PT_NODE *node = parser_new_node (this_parser, PT_DIFFERENCE);
			if (node)
			  {
			    if (isAll == PT_EMPTY)
			      isAll = PT_DISTINCT;
			    node->info.query.all_distinct = isAll;
			  }

			$$ = node;

		DBG_PRINT}}
	| INTERSECTION all_distinct
		{{

			PT_MISC_TYPE isAll = $2;
			PT_NODE *node = parser_new_node (this_parser, PT_INTERSECTION);
			if (node)
			  {
			    if (isAll == PT_EMPTY)
			      isAll = PT_DISTINCT;
			    node->info.query.all_distinct = isAll;
			  }

			$$ = node;

		DBG_PRINT}}
	| INTERSECT all_distinct
		{{

			PT_MISC_TYPE isAll = $2;
			PT_NODE *node = parser_new_node (this_parser, PT_INTERSECTION);
			if (node)
			  {
			    if (isAll == PT_EMPTY)
			      isAll = PT_DISTINCT;
			    node->info.query.all_distinct = isAll;
			  }

			$$ = node;

		DBG_PRINT}}
	;

select_or_subquery
	: select_stmt
		{{

			$$ = $1;

		DBG_PRINT}}
	| subquery
		{{

			$$ = $1;

		DBG_PRINT}}
	;

select_stmt
	:
	SELECT			/* $1 */
		{{
				/* $2 */
			PT_NODE *node;
			parser_save_found_Oracle_outer ();
			if (parser_select_level >= 0)
			  parser_select_level++;
			parser_hidden_incr_list = NULL;

			node = parser_new_node (this_parser, PT_SELECT);

			if (node)
			  {
			    node->info.query.q.select.flavor = PT_USER_SELECT;
			    node->info.query.q.select.hint = PT_HINT_NONE;
			  }

			parser_push_select_stmt_node (node);
			parser_push_hint_node (node);

		DBG_PRINT}}
	opt_hint_list 		/* $3 */
	all_distinct_distinctrow/* $4 */
	select_list 		/* $5 */
		{{
				/* $6 */
			PT_NODE *node = parser_top_select_stmt_node ();
			if (node)
			  {
			    node->info.query.q.select.list = $5;
			    if (parser_hidden_incr_list)
			      {
				(void) parser_append_node (parser_hidden_incr_list,
							   node->info.query.q.select.list);
				parser_hidden_incr_list = NULL;
			      }
			  }

		DBG_PRINT}}
	opt_select_param_list		/* $7 */
	FROM				/* $8 */
	extended_table_spec_list	/* $9 */
		{{			/* $10 */
			parser_found_Oracle_outer = false;

		DBG_PRINT}}
	opt_where_clause		/* $11 */
	opt_startwith_clause		/* $12 */
	opt_connectby_clause		/* $13 */
	opt_groupby_clause		/* $14 */
	opt_with_rollup			/* $15 */
	opt_having_clause 		/* $16 */
	opt_using_index_clause		/* $17 */
	opt_with_increment_clause	/* $18 */
		{{

			PT_NODE *n;
			bool is_dummy_select;
			PT_MISC_TYPE isAll = $4;
			PT_NODE *node = parser_pop_select_stmt_node ();
			int with_rollup = $15;
			parser_pop_hint_node ();

			is_dummy_select = false;

			if (node)
			  {
			    n = $5;
			    if (n && n->node_type == PT_VALUE && n->type_enum == PT_TYPE_STAR)
			      {
				/* select * from ... */
				is_dummy_select = true;	/* Here, guess as TRUE */
			      }
			    else if (n && n->next == NULL && n->node_type == PT_NAME
				     && n->type_enum == PT_TYPE_STAR)
			      {
				/* select A.* from */
				is_dummy_select = true;	/* Here, guess as TRUE */
			      }
			    else
			      {
				is_dummy_select = false;	/* not dummy */
			      }

			    node->info.query.into_list = $7;	/* param_list */
			    if ($7)
			      {
				is_dummy_select = false;	/* not dummy */
			      }

			    node->info.query.q.select.from = n = CONTAINER_AT_0 ($9);
			    if (n && n->next)
			      is_dummy_select = false;	/* not dummy */
			    if (TO_NUMBER (CONTAINER_AT_1 ($9)) == 1)
			      {
				PT_SELECT_INFO_SET_FLAG (node, PT_SELECT_INFO_ANSI_JOIN);
			      }

			    node->info.query.q.select.where = n = $11;
			    if (n)
			      is_dummy_select = false;	/* not dummy */
			    if (parser_found_Oracle_outer == true)
			      PT_SELECT_INFO_SET_FLAG (node, PT_SELECT_INFO_ORACLE_OUTER);

			    node->info.query.q.select.start_with = n = $12;
			    if (n)
			      is_dummy_select = false;	/* not dummy */

			    node->info.query.q.select.connect_by = n = $13;
			    if (n)
			      is_dummy_select = false;	/* not dummy */

			    node->info.query.q.select.group_by = n = $14;
			    if (n)
			      is_dummy_select = false;	/* not dummy */

			    if (with_rollup)
			      {
				if (!node->info.query.q.select.group_by)
				  {
				    PT_ERRORm (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
					       MSGCAT_SEMANTIC_WITHROLLUP_REQUIRES_GROUPBY);
				  }
				else
				  {
				    node->info.query.q.select.group_by->with_rollup = 1;
				  }
			      }

			    node->info.query.q.select.having = n = $16;
			    if (n)
			      is_dummy_select = false;	/* not dummy */

			    /* support for alias in GROUP BY */
			    n = node->info.query.q.select.group_by;
			    while (n)
			      {
				resolve_alias_in_expr_node (n, node->info.query.q.select.list);
				n = n->next;
			      }

			    /* support for alias in HAVING */
			    n = node->info.query.q.select.having;
			    while (n)
			      {
				resolve_alias_in_expr_node (n, node->info.query.q.select.list);
				n = n->next;
			      }

			    node->info.query.q.select.using_index = $17;
			    node->info.query.q.select.with_increment = $18;
			    node->info.query.id = (UINTPTR) node;
			    if (isAll == PT_EMPTY)
			      isAll = PT_ALL;
			    node->info.query.all_distinct = isAll;
			  }

			if (isAll != PT_ALL)
			  is_dummy_select = false;	/* not dummy */
			if (is_dummy_select == true)
			  {
			    /* mark as dummy */
			    PT_SELECT_INFO_SET_FLAG (node, PT_SELECT_INFO_DUMMY);
			  }

			if (parser_hidden_incr_list)
			  {
			    /* if not handle hidden expressions, raise an error */
			    PT_ERRORf (this_parser, node,
				       "%s can be used at select or with increment clause only.",
				       pt_short_print (this_parser, parser_hidden_incr_list));
			  }

			parser_restore_found_Oracle_outer ();	/* restore */
			if (parser_select_level >= 0)
			  parser_select_level--;

			$$ = node;

		DBG_PRINT}}
	| SELECT		/* $1 */
		{{
				/* $2 */
			PT_NODE *node;
			parser_save_found_Oracle_outer ();
			if (parser_select_level >= 0)
			  parser_select_level++;
			parser_hidden_incr_list = NULL;

			node = parser_new_node (this_parser, PT_SELECT);

			if (node)
			  {
			    node->info.query.q.select.flavor = PT_USER_SELECT;
			    node->info.query.q.select.hint = PT_HINT_NONE;
			  }

			parser_push_select_stmt_node (node);
			parser_push_hint_node (node);

		DBG_PRINT}}
	opt_hint_list 		/* $3 */
	select_list 		/* $4 */
		{{
				/* $5 */
			PT_NODE *node = parser_top_select_stmt_node ();
			if (node)
			  {
			    node->info.query.q.select.list = $4;
			    if (parser_hidden_incr_list)
			      {
				(void) parser_append_node (parser_hidden_incr_list,
							   node->info.query.q.select.list);
				parser_hidden_incr_list = NULL;
			      }
			  }

		DBG_PRINT}}
	opt_select_param_list	/* $6 */
		{{

			PT_NODE *n;
			PT_NODE *node = parser_pop_select_stmt_node ();
			parser_found_Oracle_outer = false;
			parser_pop_hint_node ();

			if (node)
			  {
			    n = $4;
			    if (n && n->type_enum == PT_TYPE_STAR)
			      {
				/* "select *" is not valid, raise an error */
				PT_ERRORm (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
					   MSGCAT_SEMANTIC_NO_TABLES_USED);
			      }

			    node->info.query.into_list = $6;	/* param_list */
			    node->info.query.id = (UINTPTR) node;
			    node->info.query.all_distinct = PT_ALL;
			  }

			if (parser_hidden_incr_list)
			  {
			    /* if not handle hidden expressions, raise an error */
			    PT_ERRORf (this_parser, node,
				       "%s can be used at select or with increment clause only.",
				       pt_short_print (this_parser, parser_hidden_incr_list));
			  }

			parser_restore_found_Oracle_outer ();	/* restore */
			if (parser_select_level >= 0)
			  parser_select_level--;

			$$ = node;

		DBG_PRINT}}
	;

opt_select_param_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| INTO to_param_list
		{{

			$$ = $2;

		DBG_PRINT}}
	| TO to_param_list
		{{

			$$ = $2;

		DBG_PRINT}}
	;

opt_hint_list
	: /* empty */
	| hint_list
	;

hint_list
	: hint_list CPP_STYLE_HINT
		{{

			PT_NODE *node = parser_top_hint_node ();
			char *hint_comment = $2;
			(void) pt_get_hint (hint_comment, parser_hint_table, node);

		DBG_PRINT}}
	| hint_list SQL_STYLE_HINT
		{{

			PT_NODE *node = parser_top_hint_node ();
			char *hint_comment = $2;
			(void) pt_get_hint (hint_comment, parser_hint_table, node);

		DBG_PRINT}}
	| hint_list C_STYLE_HINT
		{{

			PT_NODE *node = parser_top_hint_node ();
			char *hint_comment = $2;
			(void) pt_get_hint (hint_comment, parser_hint_table, node);

		DBG_PRINT}}
	| CPP_STYLE_HINT
		{{

			PT_NODE *node = parser_top_hint_node ();
			char *hint_comment = $1;
			(void) pt_get_hint (hint_comment, parser_hint_table, node);

		DBG_PRINT}}
	| SQL_STYLE_HINT
		{{

			PT_NODE *node = parser_top_hint_node ();
			char *hint_comment = $1;
			(void) pt_get_hint (hint_comment, parser_hint_table, node);

		DBG_PRINT}}
	| C_STYLE_HINT
		{{

			PT_NODE *node = parser_top_hint_node ();
			char *hint_comment = $1;
			(void) pt_get_hint (hint_comment, parser_hint_table, node);

		DBG_PRINT}}
	;

all_distinct_distinctrow
	: all_distinct
		{{

			$$ = $1;

		DBG_PRINT}}
	| DISTINCTROW
		{{

			$$ = PT_DISTINCT;

		DBG_PRINT}}
	;

all_distinct
	: /* empty */
		{{

			$$ = PT_EMPTY;

		DBG_PRINT}}
	| ALL
		{{

			$$ = PT_ALL;

		DBG_PRINT}}
	| DISTINCT
		{{

			$$ = PT_DISTINCT;

		DBG_PRINT}}
	| UNIQUE
		{{

			$$ = PT_DISTINCT;

		DBG_PRINT}}
	;

select_list
	: '*'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			if (node)
			  node->type_enum = PT_TYPE_STAR;
			$$ = node;

		DBG_PRINT}}
	|
		{{

			parser_save_and_set_ic (2);
			parser_save_and_set_gc (2);
			parser_save_and_set_oc (2);
			parser_save_and_set_sysc (1);
			parser_save_and_set_prc (1);
			parser_save_and_set_cbrc (1);

		DBG_PRINT}}
	  alias_enabled_expression_list
		{{

			$$ = $2;
			parser_restore_ic ();
			parser_restore_gc ();
			parser_restore_oc ();
			parser_restore_sysc ();
			parser_restore_prc ();
			parser_restore_cbrc ();

		DBG_PRINT}}
	;

alias_enabled_expression_list
	: alias_enabled_expression_list  ',' alias_enabled_expression_
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| alias_enabled_expression_
		{{

			$$ = $1;

		DBG_PRINT}}
	;

alias_enabled_expression_
	: expression_ opt_as_identifier
		{{

			PT_NODE *subq, *id;
			PT_NODE *node = $1;
			if (node->node_type == PT_VALUE && node->type_enum == PT_TYPE_EXPR_SET)
			  {
			    node->type_enum = PT_TYPE_SEQUENCE;	/* for print out */
			    PT_ERRORf (this_parser, node,
				       "check syntax at %s, illegal parentheses set expression.",
				       pt_short_print (this_parser, node));
			  }
			else if (PT_IS_QUERY_NODE_TYPE (node->node_type))
			  {
			    /* mark as single tuple query */
			    node->info.query.single_tuple = 1;

			    if ((subq = pt_get_subquery_list (node)) && subq->next)
			      {
				/* illegal multi-column subquery */
				PT_ERRORm (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
					   MSGCAT_SEMANTIC_NOT_SINGLE_COL);
			      }
			  }


			id = $2;
			if (id && id->node_type == PT_NAME)
			  {
			    if (node->type_enum == PT_TYPE_STAR)
			      {
				PT_ERROR (this_parser, id,
					  "please check syntax after '*', expecting ',' or FROM in select statement.");
			      }
			    else
			      {
				node->alias_print = pt_makename (id->info.name.original);
				parser_free_node (this_parser, id);
			      }
			  }

			$$ = node;

		DBG_PRINT}}

	;

expression_list
	: expression_list  ',' expression_
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| expression_
		{{

			$$ = $1;

		DBG_PRINT}}
	;

to_param_list
	: to_param_list ',' to_param
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| to_param
		{{

			$$ = $1;

		DBG_PRINT}}
	;

to_param
	: host_param_output
		{{

			$1->info.host_var.var_type = PT_HOST_OUT;
			$$ = $1;

		DBG_PRINT}}
	| param_
		{{

			PT_NODE *val = $1;

			if (val)
			  {
			    val->info.name.meta_class = PT_PARAMETER;
			    val->info.name.spec_id = (long) val;
			    val->info.name.resolved = pt_makename ("out parameter");
			  }

			$$ = val;

		DBG_PRINT}}
	| identifier
		{{

			PT_NODE *val = $1;

			if (val)
			  {
			    val->info.name.meta_class = PT_PARAMETER;
			    val->info.name.spec_id = (long) val;
			    val->info.name.resolved = pt_makename ("out parameter");
			  }

			$$ = val;

		DBG_PRINT}}
	;

from_param
	: host_param_input
		{{

			PT_NODE *val = $1;

			if (val)
			  {
			    val->info.name.meta_class = PT_PARAMETER;
			    val->data_type = parser_new_node (this_parser, PT_DATA_TYPE);
			  }

			$$ = val;

		DBG_PRINT}}
	| param_
		{{

			PT_NODE *val = $1;

			if (val)
			  {
			    val->info.name.meta_class = PT_PARAMETER;
			    val->data_type = parser_new_node (this_parser, PT_DATA_TYPE);
			  }

			$$ = val;

		DBG_PRINT}}
	| CLASS identifier
		{{

			PT_NODE *val = $2;

			if (val)
			  {
			    val->info.name.meta_class = PT_META_CLASS;
			    val->data_type = parser_new_node (this_parser, PT_DATA_TYPE);
			  }

			$$ = val;

		DBG_PRINT}}
	| identifier
		{{

			PT_NODE *val = $1;

			if (val)
			  {
			    val->info.name.meta_class = PT_PARAMETER;
			    val->data_type = parser_new_node (this_parser, PT_DATA_TYPE);
			  }

			$$ = val;

		DBG_PRINT}}
	;


host_param_input
	: '?'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_HOST_VAR);

			if (node)
			  {
			    node->info.host_var.var_type = PT_HOST_IN;
			    node->info.host_var.str = pt_makename ("?");
			    node->info.host_var.index = parser_input_host_index++;
			  }
			if (parser_hostvar_check == 0)
			  {
			    PT_ERRORmf(this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
				       MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "host variable");
			  }

			$$ = node;

		DBG_PRINT}}
	| PARAM_HEADER uint_text
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_HOST_VAR);

			if (node)
			  {
			    node->info.host_var.var_type = PT_HOST_IN;
			    node->info.host_var.str = pt_makename ("?");
			    node->info.host_var.index = atol ($2);
			    if (node->info.host_var.index >= parser_input_host_index)
			      {
				parser_input_host_index = node->info.host_var.index + 1;
			      }
			  }
			if (parser_hostvar_check == 0)
			  {
			    PT_ERRORmf(this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
				       MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "host variable");
			  }

			$$ = node;

		DBG_PRINT}}
	;

host_param_output
	: '?'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_HOST_VAR);

			if (node)
			  {
			    node->info.host_var.var_type = PT_HOST_IN;
			    node->info.host_var.str = pt_makename ("?");
			    node->info.host_var.index = parser_output_host_index++;
			  }

			$$ = node;

		DBG_PRINT}}
	| PARAM_HEADER uint_text
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_HOST_VAR);

			if (parent_parser == NULL)
			  {
			    /* This syntax is only permitted at internal statement parsing */
			    PT_ERRORf (this_parser, node, "check syntax at %s",
				       parser_print_tree (this_parser, node));
			  }
			else if (node)
			  {
			    node->info.host_var.var_type = PT_HOST_IN;
			    node->info.host_var.str = pt_makename ("?");
			    node->info.host_var.index = atol ($2);
			    if (node->info.host_var.index >= parser_output_host_index)
			      {
				parser_output_host_index = node->info.host_var.index + 1;
			      }
			  }

			$$ = node;

		DBG_PRINT}}
	;

param_
	: ':' identifier
		{{

			$2->info.name.meta_class = PT_PARAMETER;
			$$ = $2;

		DBG_PRINT}}
	;

opt_where_clause
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	|	{
			parser_save_and_set_ic (1);
			assert (parser_prior_check == 0);
			assert (parser_connectbyroot_check == 0);
			parser_save_and_set_sysc (1);
			parser_save_and_set_prc (1);
			parser_save_and_set_cbrc (1);
		}
	  WHERE search_condition
		{{

			parser_restore_ic ();
			parser_restore_sysc ();
			parser_restore_prc ();
			parser_restore_cbrc ();
			$$ = $3;

		DBG_PRINT}}
	;

opt_startwith_clause
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	|	{
			parser_save_and_set_pseudoc (0);
		}
	  START_ WITH search_condition
		{{

			parser_restore_pseudoc ();
			$$ = $4;

		DBG_PRINT}}
	;

opt_connectby_clause
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	|	{
			parser_save_and_set_prc (1);
			parser_save_and_set_serc (0);
			parser_save_and_set_pseudoc (0);
			parser_save_and_set_sqc (0);
		}
	  CONNECT BY opt_nocycle search_condition
		{{

			parser_restore_prc ();
			parser_restore_serc ();
			parser_restore_pseudoc ();
			parser_restore_sqc ();
			$$ = $5;

		DBG_PRINT}}
	;

opt_nocycle
	: /* empty */
	| NOCYCLE
		{{

			PT_NODE *node = parser_top_select_stmt_node ();
			if (node)
			  {
			    node->info.query.q.select.has_nocycle = true;
			  }

		DBG_PRINT}}
	;

opt_groupby_clause
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| GROUP_ BY group_spec_list
		{{

			$$ = $3;

		DBG_PRINT}}
	;

opt_with_rollup
	: /*empty*/
		{{

			$$ = 0;

		DBG_PRINT}}
	| WITH ROLLUP
		{{

			$$ = 1;

		DBG_PRINT}}
	;

group_spec_list
	: group_spec_list ',' group_spec
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| group_spec
		{{

			$$ = $1;

		DBG_PRINT}}
	;


// SR +3
group_spec
	:
		{
			parser_groupby_exception = 0;
		}
	  expression_
	  opt_asc_or_desc 	  /* $3 */
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SORT_SPEC);

			switch (parser_groupby_exception)
			  {
			  case PT_COUNT:
			  case PT_OID_ATTR:
			  case PT_INST_NUM:
			  case PT_ORDERBY_NUM:
			  case PT_ROWNUM:
			    PT_ERROR (this_parser, node,
				      "expression is not allowed as group by spec");
			    break;

			  case PT_IS_SUBINSERT:
			    PT_ERROR (this_parser, node,
				      "insert expression is not allowed as group by spec");
			    break;

			  case PT_IS_SUBQUERY:
			    PT_ERROR (this_parser, node,
				      "subquery is not allowed to group as spec");
			    break;

			  case PT_EXPR:
			    PT_ERROR (this_parser, node,
				      "search condition is not allowed as group by spec");
			    break;
			  }

			if (node)
			  {
			    node->info.sort_spec.asc_or_desc = PT_ASC;
			    node->info.sort_spec.expr = $2;
			    if ($3)
			      {
				node->info.sort_spec.asc_or_desc = PT_DESC;
			      }
			  }

			$$ = node;

		DBG_PRINT}}
	;


opt_having_clause
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	|	{ parser_save_and_set_gc(1); }
	  HAVING search_condition
		{{

			parser_restore_gc ();
			$$ = $3;

		DBG_PRINT}}
	;

opt_using_index_clause
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| USING INDEX index_name_list
		{{

			$$ = $3;

		DBG_PRINT}}
	| USING INDEX NONE
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_NAME);

			if (node)
			  {
			    node->info.name.original = NULL;
			    node->info.name.meta_class = PT_INDEX_NAME;
			  }

			$$ = node;

		DBG_PRINT}}
	| USING INDEX ALL EXCEPT index_name_list
		{{
			PT_NODE *curr;
			PT_NODE *node = parser_new_node (this_parser, PT_NAME);

			if (node)
			  {
			    node->info.name.original = NULL;
			    node->info.name.resolved = "*";
			    node->info.name.meta_class = PT_INDEX_NAME;
			    node->etc = (void *) -2;
			  }

			node->next = $5;
			for (curr = node; curr; curr = curr->next)
			  {
			    curr->etc = (void*) -2;
			  }

			$$ = node;

		DBG_PRINT}}
	;

index_name_list
	: index_name_list ',' index_name
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| index_name
		{{

			$$ = $1;

		DBG_PRINT}}
	;

index_name
	: class_name paren_plus
		{{

			PT_NODE *node = $1;
			node->info.name.meta_class = PT_INDEX_NAME;
			node->etc = (void *) 1;
			$$ = node;

		DBG_PRINT}}
	| class_name paren_minus
		{{

			PT_NODE *node = $1;
			node->info.name.meta_class = PT_INDEX_NAME;
			node->etc = (void *) -1;
			$$ = node;

		DBG_PRINT}}
	| class_name
		{{

			PT_NODE *node = $1;
			node->info.name.meta_class = PT_INDEX_NAME;
			$$ = node;

		DBG_PRINT}}
	;

opt_with_increment_clause
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| WITH INCREMENT For incr_arg_name_list__inc
		{{

			$$ = $4;

		DBG_PRINT}}
	| WITH DECREMENT For incr_arg_name_list__dec
		{{

			$$ = $4;

		DBG_PRINT}}
	;

incr_arg_name_list__inc
	: incr_arg_name_list__inc ',' incr_arg_name__inc
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| incr_arg_name__inc
		{{

			$$ = $1;

		DBG_PRINT}}
	;

incr_arg_name__inc
	: path_expression
		{{
			PT_NODE *node = $1;

			if (node->node_type == PT_EXPR && node->info.expr.op == PT_INCR)
			  {
			    /* do nothing */
			  }
			else if (node->node_type == PT_EXPR && node->info.expr.op == PT_DECR)
			  {
			    PT_ERRORf2 (this_parser, node, "%s can be used at 'with %s for'.",
					pt_short_print (this_parser, node), "increment");
			  }
			else
			  {
			    node = parser_make_expression (PT_INCR, $1, NULL, NULL);
                            node->is_hidden_column = 1;
			  }

			$$ = node;
		DBG_PRINT}}
	;

incr_arg_name_list__dec
	: incr_arg_name_list__dec ',' incr_arg_name__dec
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| incr_arg_name__dec
		{{

			$$ = $1;

		DBG_PRINT}}
	;

incr_arg_name__dec
	: path_expression
		{{
			PT_NODE *node = $1;

			if (node->node_type == PT_EXPR && node->info.expr.op == PT_INCR)
			  {
			    PT_ERRORf2 (this_parser, node, "%s can be used at 'with %s for'.",
					pt_short_print (this_parser, node), "increment");
			  }
			else if (node->node_type == PT_EXPR && node->info.expr.op == PT_DECR)
			  {
			    /* do nothing */
			  }
			else
			  {
			    node = parser_make_expression (PT_DECR, $1, NULL, NULL);
                            node->is_hidden_column = 1;
			  }

			$$ = node;
		DBG_PRINT}}
	;


opt_orderby_clause
	: /* empty */
		{ $$ = NULL; }
	| ORDER
	  opt_siblings
	  BY
		{{

			PT_NODE *stmt = parser_top_orderby_node ();

			if (!stmt->info.query.order_siblings)
			  {
				parser_save_and_set_sysc (1);
				parser_save_and_set_prc (1);
				parser_save_and_set_cbrc (1);
				parser_save_and_set_pseudoc (1);
			  }
			else
			  {
				parser_save_and_set_sysc (0);
				parser_save_and_set_prc (0);
				parser_save_and_set_cbrc (0);
				parser_save_and_set_pseudoc (0);
			  }

			if (stmt && !stmt->info.query.q.select.from)
			    PT_ERRORmf(this_parser, pt_top(this_parser),
				MSGCAT_SET_PARSER_SEMANTIC,
				MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "ORDER BY");

		DBG_PRINT}}
	  sort_spec_list
		{{

			PT_NODE *stmt = parser_top_orderby_node ();

			parser_restore_sysc ();
			parser_restore_prc ();
			parser_restore_cbrc ();
			parser_restore_pseudoc ();
			parser_save_and_set_oc (1);

		DBG_PRINT}}
	  opt_for_search_condition
		{{

			PT_NODE *col, *order, *n, *temp, *list = NULL;
			PT_NODE *stmt = parser_top_orderby_node ();
			bool found_star;
			int index_of_col;
			char *n_str, *c_str;
			bool is_col, is_alias;

			parser_restore_oc ();
			if (stmt)
			  {
			    stmt->info.query.orderby_for = $7;
			    /* support for alias in FOR */
			    n = stmt->info.query.orderby_for;
			    while (n)
			      {
				resolve_alias_in_expr_node (n, stmt->info.query.q.select.list);
				n = n->next;
			      }
			  }

			if (stmt)
			  {
			    stmt->info.query.order_by = order = $5;
			    if (order)
			      {				/* not dummy */
				PT_SELECT_INFO_CLEAR_FLAG (stmt, PT_SELECT_INFO_DUMMY);
				if (pt_is_query (stmt))
				  {
				    /* UNION, INTERSECT, DIFFERENCE, SELECT */
				    temp = stmt;
				    while (temp)
				      {
					switch (temp->node_type)
					  {
					  case PT_SELECT:
					    goto start_check;
					    break;
					  case PT_UNION:
					  case PT_INTERSECTION:
					  case PT_DIFFERENCE:
					    temp = temp->info.query.q.union_.arg1;
					    break;
					  default:
					    temp = NULL;
					    break;
					  }
				      }

				  start_check:
				    if (temp)
				      {
				        list = temp->info.query.q.select.list;
				      }
				    found_star = false;

				    if (list && list->node_type == PT_VALUE
					&& list->type_enum == PT_TYPE_STAR)
				      {
					/* found "*" */
					found_star = true;
				      }
				    else
				      {
					for (col = list; col; col = col->next)
					  {
					    if (col->node_type == PT_NAME
						&& col->type_enum == PT_TYPE_STAR)
					      {
						/* found "classname.*" */
						found_star = true;
						break;
					      }
					  }
				      }

				    for (; order; order = order->next)
				      {
					is_alias = false;
					is_col = false;

					n = order->info.sort_spec.expr;
					if (n == NULL)
					  {
					    break;
					  }

					if (n->node_type == PT_VALUE)
					  {
					    continue;
					  }

					n_str = parser_print_tree (this_parser, n);
					if (n_str == NULL)
					  {
					    continue;
					  }

					for (col = list, index_of_col = 1; col;
					     col = col->next, index_of_col++)
					  {
					    c_str = parser_print_tree (this_parser, col);
					    if (c_str == NULL)
					      {
					        continue;
					      }

					    if ((col->alias_print
						 && intl_mbs_namecmp (n_str, col->alias_print) == 0
						 && (is_alias = true))
						|| (intl_mbs_namecmp (n_str, c_str) == 0
						    && (is_col = true)))
					      {
						if (found_star)
						  {
						    temp = parser_copy_tree (this_parser, col);
						    temp->next = NULL;
						  }
						else
						  {
						    temp = parser_new_node (this_parser, PT_VALUE);
						    if (temp == NULL)
						      {
						        break;
						      }

						    temp->type_enum = PT_TYPE_INTEGER;
						    temp->info.value.data_value.i = index_of_col;
						  }

						parser_free_node (this_parser, n);
						order->info.sort_spec.expr = temp;

						if (is_col == true && is_alias == true)
						  {
						    /* alias/col name ambiguity, raise error */
						    PT_ERRORmf (this_parser, order, MSGCAT_SET_PARSER_SEMANTIC,
								MSGCAT_SEMANTIC_AMBIGUOUS_COLUMN_IN_ORDERING,
								n_str);
						    break;
						  }
					      }
					  }
				      }
				  }
			      }
			  }

			$$ = stmt;

		DBG_PRINT}}
	;

opt_siblings
	: /* empty */
	| SIBLINGS
		{{

			PT_NODE *stmt = parser_top_orderby_node ();
			stmt->info.query.order_siblings = true;
			if (stmt->info.query.q.select.connect_by == NULL)
			    {
				PT_ERRORmf(this_parser, stmt,
				    MSGCAT_SET_PARSER_SEMANTIC,
				    MSGCAT_SEMANTIC_NOT_HIERACHICAL_QUERY,
				    "SIBLINGS");
			    }

		DBG_PRINT}}
	;

opt_uint_or_host_input
	: unsigned_integer
		{{

			$$ = $1;

		DBG_PRINT}}
	| host_param_input
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_select_limit_clause
	: /* empty */
	| LIMIT opt_uint_or_host_input
		{{

			PT_NODE *node = parser_top_orderby_node ();
			if (node)
			  {
			    node->info.query.q.select.limit = $2;

			    if (!node->info.query.q.select.from)
			      {
				PT_ERRORm (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
					   MSGCAT_SEMANTIC_NO_TABLES_USED);
			      }

			    /* For queries that have LIMIT clause don't allow
			     * inst_num, groupby_num, orderby_num in where, having, for
			     * respectively.
			     */
			    if (node->info.query.orderby_for)
			      {
				bool ordbynum_flag = false;
				(void) parser_walk_tree (this_parser, node->info.query.orderby_for,
							 pt_check_orderbynum_pre, NULL,
							 pt_check_orderbynum_post, &ordbynum_flag);
				if (ordbynum_flag)
				  {
				    PT_ERRORmf(this_parser, node->info.query.orderby_for,
					       MSGCAT_SET_PARSER_SEMANTIC,
					       MSGCAT_SEMANTIC_NOT_ALLOWED_IN_LIMIT_CLAUSE, "ORDERBY_NUM()");
				  }
			      }
			    if (node->info.query.q.select.having)
			      {
				bool grbynum_flag = false;
				(void) parser_walk_tree (this_parser, node->info.query.q.select.having,
							 pt_check_groupbynum_pre, NULL,
							 pt_check_groupbynum_post, &grbynum_flag);
				if (grbynum_flag)
				  {
				    PT_ERRORmf(this_parser, node->info.query.q.select.having,
					       MSGCAT_SET_PARSER_SEMANTIC,
					       MSGCAT_SEMANTIC_NOT_ALLOWED_IN_LIMIT_CLAUSE, "GROUPBY_NUM()");
				  }
			      }
			    if (node->info.query.q.select.where)
			      {
				bool instnum_flag = false;
				(void) parser_walk_tree (this_parser, node->info.query.q.select.where,
							 pt_check_instnum_pre, NULL,
							 pt_check_instnum_post, &instnum_flag);
				if (instnum_flag)
				  {
				    PT_ERRORmf(this_parser, node->info.query.q.select.where,
					       MSGCAT_SET_PARSER_SEMANTIC,
					       MSGCAT_SEMANTIC_NOT_ALLOWED_IN_LIMIT_CLAUSE, "INST_NUM()/ROWNUM");
				  }
			      }
			  }

		DBG_PRINT}}
	| LIMIT opt_uint_or_host_input ',' opt_uint_or_host_input
		{{

			PT_NODE *node = parser_top_orderby_node ();
			if (node)
			  {
			    PT_NODE *limit1 = $2;
			    PT_NODE *limit2 = $4;
			    if (limit1)
			      {
				limit1->next = limit2;
			      }
			    node->info.query.q.select.limit = limit1;

			    if (!node->info.query.q.select.from)
			      {
				PT_ERRORm (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
					   MSGCAT_SEMANTIC_NO_TABLES_USED);
			      }

			    /* For queries that have LIMIT clause don't allow
			     * inst_num, groupby_num, orderby_num in where, having, for
			     * respectively.
			     */
			    if (node->info.query.orderby_for)
			      {
				bool ordbynum_flag = false;
				(void) parser_walk_tree (this_parser, node->info.query.orderby_for,
							 pt_check_orderbynum_pre, NULL,
							 pt_check_orderbynum_post, &ordbynum_flag);
				if (ordbynum_flag)
				  {
				    PT_ERRORmf(this_parser, node->info.query.orderby_for,
					       MSGCAT_SET_PARSER_SEMANTIC,
					       MSGCAT_SEMANTIC_NOT_ALLOWED_IN_LIMIT_CLAUSE, "ORDERBY_NUM()");
				  }
			      }
			    if (node->info.query.q.select.having)
			      {
				bool grbynum_flag = false;
				(void) parser_walk_tree (this_parser, node->info.query.q.select.having,
							 pt_check_groupbynum_pre, NULL,
							 pt_check_groupbynum_post, &grbynum_flag);
				if (grbynum_flag)
				  {
				    PT_ERRORmf(this_parser, node->info.query.q.select.having,
					       MSGCAT_SET_PARSER_SEMANTIC,
					       MSGCAT_SEMANTIC_NOT_ALLOWED_IN_LIMIT_CLAUSE, "GROUPBY_NUM()");
				  }
			      }
			    if (node->info.query.q.select.where)
			      {
				bool instnum_flag = false;
				(void) parser_walk_tree (this_parser, node->info.query.q.select.where,
							 pt_check_instnum_pre, NULL,
							 pt_check_instnum_post, &instnum_flag);
				if (instnum_flag)
				  {
				    PT_ERRORmf(this_parser, node->info.query.q.select.where,
					       MSGCAT_SET_PARSER_SEMANTIC,
					       MSGCAT_SEMANTIC_NOT_ALLOWED_IN_LIMIT_CLAUSE, "INST_NUM()/ROWNUM");
				  }
			      }
			  }

		DBG_PRINT}}
	;

opt_upd_del_limit_clause
	: /* empty */
		{ $$ = NULL; }
	| LIMIT opt_uint_or_host_input
		{{

			  $$ = $2;

		DBG_PRINT}}
	;

opt_for_search_condition
	: /* empty */
		{ $$ = NULL; }
	| For search_condition
		{ $$ = $2; }
	;

sort_spec_list
	: sort_spec_list ',' sort_spec
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| sort_spec
		{{

			$$ = $1;

		DBG_PRINT}}
	;

sort_spec
	: expression_ ASC
		{{
			PT_NODE *node = parser_new_node (this_parser, PT_SORT_SPEC);

			if (node)
			  {
			    node->info.sort_spec.asc_or_desc = PT_ASC;
			    node->info.sort_spec.expr = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	| expression_ DESC
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SORT_SPEC);

			if (node)
			  {
			    node->info.sort_spec.asc_or_desc = PT_DESC;
			    node->info.sort_spec.expr = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	| expression_
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_SORT_SPEC);

			if (node)
			  {
			    node->info.sort_spec.asc_or_desc = PT_ASC;
			    node->info.sort_spec.expr = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	;


expression_
	: expression_ STRCAT expression_bitor
		{{

			$$ = parser_make_expression (PT_STRCAT, $1, $3, NULL);

		DBG_PRINT}}
	| expression_bitor
		{{

			$$ = $1;

		DBG_PRINT}}
	;

expression_bitor
	: expression_bitor '|' expression_bitand
		{{

			$$ = parser_make_expression (PT_BIT_OR, $1, $3, NULL);

		DBG_PRINT}}
	| expression_bitand
		{{

			$$ = $1;

		DBG_PRINT}}
	;

expression_bitand
	: expression_bitand '&' expression_bitshift
		{{

			$$ = parser_make_expression (PT_BIT_AND, $1, $3, NULL);

		DBG_PRINT}}
	| expression_bitshift
		{{

			$$ = $1;

		DBG_PRINT}}
	;

expression_bitshift
	: expression_bitshift BITSHIFT_LEFT expression_add_sub
		{{

			$$ = parser_make_expression (PT_BITSHIFT_LEFT, $1, $3, NULL);

		DBG_PRINT}}
	| expression_bitshift BITSHIFT_RIGHT expression_add_sub
		{{

			$$ = parser_make_expression (PT_BITSHIFT_RIGHT, $1, $3, NULL);

		DBG_PRINT}}
	| expression_add_sub
		{{

			$$ = $1;

		DBG_PRINT}}
	;

expression_add_sub
	: expression_add_sub '+' term
		{{

			$$ = parser_make_expression (PT_PLUS, $1, $3, NULL);

		DBG_PRINT}}
	| expression_add_sub '-' term
		{{

			$$ = parser_make_expression (PT_MINUS, $1, $3, NULL);

		DBG_PRINT}}
	| term
		{{

			$$ = $1;

		DBG_PRINT}}
	;

term
	: term '*' factor
		{{

			$$ = parser_make_expression (PT_TIMES, $1, $3, NULL);

		DBG_PRINT}}
	| term '/' factor
		{{

			$$ = parser_make_expression (PT_DIVIDE, $1, $3, NULL);

		DBG_PRINT}}
	| term DIV factor
		{{

			$$ = parser_make_expression (PT_DIV, $1, $3, NULL);

		DBG_PRINT}}
	| term MOD factor
		{{

			$$ = parser_make_expression (PT_MOD, $1, $3, NULL);

		DBG_PRINT}}
	| factor
		{{

			$$ = $1;

		DBG_PRINT}}
	;

factor
	: factor '^' factor_
		{{

			$$ = parser_make_expression (PT_BIT_XOR, $1, $3, NULL);

		DBG_PRINT}}
	| factor_
		{{

			$$ = $1;

		DBG_PRINT}}
	;

factor_
	: opt_plus primary
		{{

			$$ = $2;

		DBG_PRINT}}
	| '-' primary
		{{

			$$ = parser_make_expression (PT_UNARY_MINUS, $2, NULL, NULL);

		DBG_PRINT}}
	| '~' primary
		{{

			$$ = parser_make_expression (PT_BIT_NOT, $2, NULL, NULL);

		DBG_PRINT}}
	| PRIOR
		{{

			parser_save_and_set_sysc (0);
			parser_save_and_set_prc (0);
			parser_save_and_set_cbrc (0);
			parser_save_and_set_pseudoc (0);

		DBG_PRINT}}
	  primary
		{{

			PT_NODE *node = parser_make_expression (PT_PRIOR, $3, NULL, NULL);

			parser_restore_sysc ();
			parser_restore_prc ();
			parser_restore_cbrc ();
			parser_restore_pseudoc ();

			if (parser_prior_check == 0)
			  {
				PT_ERRORmf(this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
				  MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "PRIOR");
			  }

			$$ = node;

		DBG_PRINT}}
	| CONNECT_BY_ROOT
		{{

			parser_save_and_set_sysc (0);
			parser_save_and_set_prc (0);
			parser_save_and_set_cbrc (0);
			parser_save_and_set_pseudoc (0);

		DBG_PRINT}}
	  primary
		{{

			PT_NODE *node = parser_make_expression (PT_CONNECT_BY_ROOT, $3, NULL, NULL);

			parser_restore_sysc ();
			parser_restore_prc ();
			parser_restore_cbrc ();
			parser_restore_pseudoc ();

			if (parser_connectbyroot_check == 0)
			  {
				PT_ERRORmf(this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
				  MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "CONNECT_BY_ROOT");
			  }

			$$ = node;

		DBG_PRINT}}
	;

primary
	: pseudo_column		%dprec 11
		{{

			if (parser_pseudocolumn_check == 0)
			  PT_ERRORmf (this_parser, $1, MSGCAT_SET_PARSER_SEMANTIC,
				MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "Pseudo-column");

			$$ = $1;

		DBG_PRINT}}
	| reserved_func		%dprec 10
		{{

			$$ = $1;

		DBG_PRINT}}
	| case_expr		%dprec 9
		{{

			$$ = $1;

		DBG_PRINT}}
	| extract_expr		%dprec 8
		{{

			$$ = $1;

		DBG_PRINT}}
	| literal_w_o_param	%dprec 7
		{{

			$$ = $1;

		DBG_PRINT}}
	| insert_expression	%dprec 6
		{{

			$1->info.insert.is_subinsert = PT_IS_SUBINSERT;
			$$ = $1;
			parser_groupby_exception = PT_IS_SUBINSERT;

		DBG_PRINT}}
	| path_expression	%dprec 5
		{{

			$$ = $1;

		DBG_PRINT}}
	| '(' expression_list ')' %dprec 4
		{{
			PT_NODE *exp = $2;
			PT_NODE *val, *tmp;

			bool is_single_expression = true;
			if (exp && exp->next != NULL)
			  {
			    is_single_expression = false;
			  }

			if (is_single_expression)
			  {
			    if (exp && exp->node_type == PT_EXPR)
			      {
				exp->info.expr.paren_type = 1;
			      }

			    if (exp)
			      {
				exp->is_paren = 1;
			      }

			    $$ = exp;
			  }
			else
			  {
			    val = parser_new_node (this_parser, PT_VALUE);
			    if (val)
			      {
				for (tmp = exp; tmp; tmp = tmp->next)
				  {
				    if (tmp->node_type == PT_VALUE && tmp->type_enum == PT_TYPE_EXPR_SET)
				      {
					tmp->type_enum = PT_TYPE_SEQUENCE;
				      }
				  }

				val->info.value.data_value.set = exp;
				val->type_enum = PT_TYPE_EXPR_SET;
			      }

			    exp = val;
			    $$ = exp;
			    parser_groupby_exception = PT_EXPR;
			  }

		DBG_PRINT}}
	| '(' search_condition_query ')' %dprec 2
		{{

			PT_NODE *exp = $2;

			if (exp && exp->node_type == PT_EXPR)
			  {
			    exp->info.expr.paren_type = 1;
			  }

			$$ = exp;
			parser_groupby_exception = PT_EXPR;

		DBG_PRINT}}
	| subquery    %dprec 1
		{{
			parser_groupby_exception = PT_IS_SUBQUERY;
			$$ = $1;
		DBG_PRINT}}
	;

search_condition_query
	: search_condition_expression
		{{

			PT_NODE *node = $1;
			parser_push_orderby_node (node);

		DBG_PRINT}}
	  opt_orderby_clause
		{{

			PT_NODE *node = parser_pop_orderby_node ();
			$$ = node;

		DBG_PRINT}}
	;

search_condition_expression
	: search_condition_expression table_op select_or_subquery
		{{

			PT_NODE *node = $2;
			if (node)
			  {
			    node->info.query.q.union_.arg1 = $1;
			    node->info.query.q.union_.arg2 = $3;
			  }

			$$ = node;

		DBG_PRINT}}
	| search_condition
		{{

			$$ = $1;

		DBG_PRINT}}
	;

pseudo_column
	: CONNECT_BY_ISCYCLE
		{{

			$$ = parser_make_expression (PT_CONNECT_BY_ISCYCLE, NULL, NULL, NULL);

		DBG_PRINT}}
	| CONNECT_BY_ISLEAF
		{{

			$$ = parser_make_expression (PT_CONNECT_BY_ISLEAF, NULL, NULL, NULL);

		DBG_PRINT}}
	| LEVEL
		{{

			$$ = parser_make_expression (PT_LEVEL, NULL, NULL, NULL);

		DBG_PRINT}}
	;


reserved_func
	: COUNT '(' '*' ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_FUNCTION);

			if (node)
			  {
			    node->info.function.arg_list = NULL;
			    node->info.function.function_type = PT_COUNT_STAR;
			  }


			$$ = node;
			parser_groupby_exception = PT_COUNT;

		DBG_PRINT}}
	| COUNT '(' of_distinct_unique expression_ ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_FUNCTION);

			if (node)
			  {
			    node->info.function.all_or_distinct = PT_DISTINCT;
			    node->info.function.function_type = PT_COUNT;
			    node->info.function.arg_list = $4;
			  }

			$$ = node;
			parser_groupby_exception = PT_COUNT;

		DBG_PRINT}}
	| COUNT '(' opt_all expression_ ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_FUNCTION);

			if (node)
			  {
			    node->info.function.all_or_distinct = PT_ALL;
			    node->info.function.function_type = PT_COUNT;
			    node->info.function.arg_list = $4;
			  }

			$$ = node;
			parser_groupby_exception = PT_COUNT;

		DBG_PRINT}}
	| of_avg_max_etc '(' of_distinct_unique path_expression ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_FUNCTION);
			node->info.function.function_type = $1;

			if ($1 == PT_MAX || $1 == PT_MIN)
			  node->info.function.all_or_distinct = PT_ALL;
			else
			  node->info.function.all_or_distinct = PT_DISTINCT;

			node->info.function.arg_list = $4;

			$$ = node;
			parser_groupby_exception = PT_COUNT;

		DBG_PRINT}}
	| of_avg_max_etc '(' opt_all expression_ ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_FUNCTION);

			if (node)
			  {
			    node->info.function.function_type = $1;
			    node->info.function.all_or_distinct = PT_ALL;
			    node->info.function.arg_list = $4;
			  }

			$$ = node;
			parser_groupby_exception = PT_COUNT;

		DBG_PRINT}}
	| POSITION '(' expression_ IN_ expression_ ')'
		{{

			$$ = parser_make_expression (PT_POSITION, $3, $5, NULL);

		DBG_PRINT}}
	| SUBSTRING_
		{ push_msg(MSGCAT_SYNTAX_INVALID_SUBSTRING); }
	  '(' expression_ FROM expression_ For expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_SUBSTRING, $4, $6, $8);
			node->info.expr.qualifier = PT_SUBSTR_ORG;
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| SUBSTRING_
		{ push_msg(MSGCAT_SYNTAX_INVALID_SUBSTRING); }
	  '(' expression_ FROM expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_SUBSTRING, $4, $6, NULL);
			node->info.expr.qualifier = PT_SUBSTR_ORG;
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| SUBSTRING_
		{ push_msg(MSGCAT_SYNTAX_INVALID_SUBSTRING); }
	  '(' expression_ ',' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_SUBSTRING, $4, $6, $8);
			node->info.expr.qualifier = PT_SUBSTR_ORG;
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| SUBSTRING_
		{ push_msg(MSGCAT_SYNTAX_INVALID_SUBSTRING); }
	  '(' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_SUBSTRING, $4, $6, NULL);
			node->info.expr.qualifier = PT_SUBSTR_ORG;
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| Date
		{ push_msg(MSGCAT_SYNTAX_INVALID_DATE); }
	  '(' expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_DATEF, $4, NULL, NULL);
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| ADDDATE
		{ push_msg(MSGCAT_SYNTAX_INVALID_ADDDATE); }
	  '(' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_ADDDATE, $4, $6, NULL);
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| adddate_name
		{ push_msg(MSGCAT_SYNTAX_INVALID_DATE_ADD); }
	  '(' expression_ ',' INTERVAL expression_ datetime_field ')'
		{ pop_msg(); }
		{{

			PT_NODE *node;
			PT_NODE *node_unit = parser_new_node (this_parser, PT_VALUE);

			if (node_unit)
			  {
			    node_unit->info.expr.qualifier = $8;
			    node_unit->type_enum = PT_TYPE_INTEGER;
			  }

			node = parser_make_expression (PT_DATE_ADD, $4, $7, node_unit);
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| SUBDATE
		{ push_msg(MSGCAT_SYNTAX_INVALID_SUBDATE); }
	  '(' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_SUBDATE, $4, $6, NULL);
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| subdate_name
		{ push_msg(MSGCAT_SYNTAX_INVALID_DATE_SUB); }
	  '(' expression_ ',' INTERVAL expression_ datetime_field ')'
		{ pop_msg(); }
		{{

			PT_NODE *node;
			PT_NODE *node_unit = parser_new_node (this_parser, PT_VALUE);

			if (node_unit)
			  {
			    node_unit->info.expr.qualifier = $8;
			    node_unit->type_enum = PT_TYPE_INTEGER;
			  }

			node = parser_make_expression (PT_DATE_SUB, $4, $7, node_unit);
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| TIMESTAMP
		{ push_msg(MSGCAT_SYNTAX_INVALID_TIMESTAMP); }
		'(' expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_TIMESTAMP, $4, NULL, NULL); /* 1 parameter */
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| TIMESTAMP
		{ push_msg(MSGCAT_SYNTAX_INVALID_TIMESTAMP); }
		'(' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_TIMESTAMP, $4, $6, NULL); /* 2 parameters */
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| DATABASE
		{ push_msg(MSGCAT_SYNTAX_INVALID_DATABASE); }
	  '(' ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_DATABASE, NULL, NULL, NULL);
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| SCHEMA
		{ push_msg(MSGCAT_SYNTAX_INVALID_SCHEMA); }
	  '(' ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_SCHEMA, NULL, NULL, NULL);
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| TRIM
		{ push_msg(MSGCAT_SYNTAX_INVALID_TRIM); }
	  '(' of_leading_trailing_both expression_ FROM expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_TRIM, $7, $5, NULL);
			node->info.expr.qualifier = $4;
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| TRIM
		{ push_msg(MSGCAT_SYNTAX_INVALID_TRIM); }
	  '(' of_leading_trailing_both FROM expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_TRIM, $6, NULL, NULL);
			node->info.expr.qualifier = $4;
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| TRIM
		{ push_msg(MSGCAT_SYNTAX_INVALID_TRIM); }
	  '(' expression_ FROM  expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_TRIM, $6, $4, NULL);
			node->info.expr.qualifier = PT_BOTH;
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| TRIM
		{ push_msg(MSGCAT_SYNTAX_INVALID_TRIM); }
	  '(' expression_ ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_TRIM, $4, NULL, NULL);
			node->info.expr.qualifier = PT_BOTH;
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| CAST
		{ push_msg(MSGCAT_SYNTAX_INVALID_CAST); }
	  '(' expression_ AS data_type ')'
		{ pop_msg(); }
		{{

			PT_NODE *expr = parser_make_expression (PT_CAST, $4, NULL, NULL);
			PT_TYPE_ENUM typ = TO_NUMBER (CONTAINER_AT_0 ($6));
			PT_NODE *dt = CONTAINER_AT_1 ($6);
			PT_NODE *set_dt;

			if (!dt)
			  {
			    dt = parser_new_node (this_parser, PT_DATA_TYPE);
			    dt->type_enum = TO_NUMBER (CONTAINER_AT_0 ($6));
			    dt->data_type = NULL;
			  }
			else if (typ == PT_TYPE_SET || typ == PT_TYPE_MULTISET
				 || typ == PT_TYPE_SEQUENCE)
			  {
			    set_dt = parser_new_node (this_parser, PT_DATA_TYPE);
			    set_dt->type_enum = typ;
			    set_dt->data_type = dt;
			    dt = set_dt;
			  }

			expr->info.expr.cast_type = dt;
			$$ = expr;

		DBG_PRINT}}
	| CLASS '(' identifier ')'
		{{

			$3->info.name.meta_class = PT_OID_ATTR;
			$$ = $3;
			parser_groupby_exception = PT_OID_ATTR;

		DBG_PRINT}}
	| of_dates
		{{

			PT_NODE *expr = parser_make_expression (PT_SYS_DATE, NULL, NULL, NULL);
			$$ = expr;

		DBG_PRINT}}
	| of_times
		{{

			PT_NODE *expr = parser_make_expression (PT_SYS_TIME, NULL, NULL, NULL);
			$$ = expr;

		DBG_PRINT}}
	| of_timestamps
		{{

			PT_NODE *expr = parser_make_expression (PT_SYS_TIMESTAMP, NULL, NULL, NULL);
			$$ = expr;

		DBG_PRINT}}
	| of_datetimes
		{{

			PT_NODE *expr = parser_make_expression (PT_SYS_DATETIME, NULL, NULL, NULL);
			$$ = expr;

		DBG_PRINT}}
	| of_users
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_EXPR);
			if (node)
			  node->info.expr.op = PT_CURRENT_USER;

			parser_cannot_cache = true;
			$$ = node;

		DBG_PRINT}}
	| of_users
		{ push_msg(MSGCAT_SYNTAX_INVALID_SYSTEM_USER); }
	  '(' ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_USER, NULL, NULL, NULL);
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| DEFAULT '('
		{ push_msg(MSGCAT_SYNTAX_INVALID_DEFAULT); }
	  simple_path_id ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = NULL;
			PT_NODE *path = $4;

			if (path != NULL)
			  {
			    pt_set_fill_default_in_path_expression (path);
			    node = parser_make_expression (PT_DEFAULTF, path, NULL, NULL);
			    PICE (node);
			  }
			$$ = node;

		DBG_PRINT}}
	| LOCAL_TRANSACTION_ID
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_EXPR);
			if (node)
			  node->info.expr.op = PT_LOCAL_TRANSACTION_ID;

			parser_si_tran_id = true;
			parser_cannot_cache = true;
			$$ = node;

		DBG_PRINT}}
	| ROWNUM
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_EXPR);

			if (node)
			  {
			    node->info.expr.op = PT_ROWNUM;
			    PT_EXPR_INFO_SET_FLAG (node, PT_EXPR_INFO_INSTNUM_C);
			  }

			$$ = node;
			parser_groupby_exception = PT_ROWNUM;

			if (parser_instnum_check == 0)
			  PT_ERRORmf2 (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
				       MSGCAT_SEMANTIC_INSTNUM_COMPATIBILITY_ERR,
				       "INST_NUM() or ROWNUM", "INST_NUM() or ROWNUM");

		DBG_PRINT}}
	| ADD_MONTHS
		{ push_msg(MSGCAT_SYNTAX_INVALID_ADD_MONTHS); }
	  '(' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_ADD_MONTHS, $4, $6, NULL);

		DBG_PRINT}}
	| OCTET_LENGTH
		{ push_msg(MSGCAT_SYNTAX_INVALID_OCTET_LENGTH); }
	  '(' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_OCTET_LENGTH, $4, NULL, NULL);

		DBG_PRINT}}
	| BIT_LENGTH
		{ push_msg(MSGCAT_SYNTAX_INVALID_BIT_LENGTH); }
	  '(' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_BIT_LENGTH, $4, NULL, NULL);

		DBG_PRINT}}
	| LOWER
		{ push_msg(MSGCAT_SYNTAX_INVALID_LOWER); }
	  '(' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_LOWER, $4, NULL, NULL);

		DBG_PRINT}}
	| LCASE
		{ push_msg(MSGCAT_SYNTAX_INVALID_LOWER); }
	  '(' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_LOWER, $4, NULL, NULL);

		DBG_PRINT}}
	| UPPER
		{ push_msg(MSGCAT_SYNTAX_INVALID_UPPER); }
	  '(' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_UPPER, $4, NULL, NULL);

		DBG_PRINT}}
	| UCASE
		{ push_msg(MSGCAT_SYNTAX_INVALID_UPPER); }
	  '(' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_UPPER, $4, NULL, NULL);

		DBG_PRINT}}
	| SYS_CONNECT_BY_PATH
		{{

			push_msg(MSGCAT_SYNTAX_INVALID_SYS_CONNECT_BY_PATH);

			parser_save_and_set_sysc (0);
			parser_save_and_set_prc (0);
			parser_save_and_set_cbrc (0);
			parser_save_and_set_pseudoc (0);

		}}
	  '(' expression_ ',' char_string_literal ')'
		{ pop_msg(); }
		{{

			PT_NODE *node = parser_make_expression (PT_SYS_CONNECT_BY_PATH, $4, $6, NULL);

			parser_restore_sysc ();
			parser_restore_prc ();
			parser_restore_cbrc ();
			parser_restore_pseudoc ();
			if (parser_sysconnectbypath_check == 0)
			  {
				PT_ERRORmf(this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
				  MSGCAT_SEMANTIC_NOT_ALLOWED_HERE, "SYS_CONNECT_BY_PATH");
			  }
			$$ = node;

		DBG_PRINT}}
	| IF
		{ push_msg (MSGCAT_SYNTAX_INVALID_IF); }
	  '(' search_condition ',' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_IF, $4, $6, $8);

		DBG_PRINT}}
	| IFNULL
		{ push_msg (MSGCAT_SYNTAX_INVALID_IFNULL); }
	  '(' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_IFNULL, $4, $6, NULL);

		DBG_PRINT}}
	| ISNULL
		{ push_msg (MSGCAT_SYNTAX_INVALID_ISNULL); }
	  '(' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_ISNULL, $4, NULL, NULL);

		DBG_PRINT}}
	| LEFT
		{ push_msg(MSGCAT_SYNTAX_INVALID_LEFT); }
	  '(' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{
			PT_NODE *node =
			  parser_make_expression (PT_LEFT, $4, $6, NULL);
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| RIGHT
		{ push_msg(MSGCAT_SYNTAX_INVALID_RIGHT); }
	  '(' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{
			PT_NODE *node =
			  parser_make_expression (PT_RIGHT, $4, $6, NULL);
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| MOD
		{ push_msg(MSGCAT_SYNTAX_INVALID_MODULUS); }
	  '(' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{
			PT_NODE *node =
			  parser_make_expression (PT_MODULUS, $4, $6, NULL);
			PICE (node);
			$$ = node;

		DBG_PRINT}}
	| TRUNCATE
		{ push_msg(MSGCAT_SYNTAX_INVALID_TRUNCATE); }
	  '(' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_TRUNC, $4, $6, NULL);

		DBG_PRINT}}
	| TRANSLATE
		{ push_msg(MSGCAT_SYNTAX_INVALID_TRANSLATE); }
	  '(' expression_  ',' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_TRANSLATE, $4, $6, $8);

		DBG_PRINT}}
	| REPLACE
		{ push_msg(MSGCAT_SYNTAX_INVALID_TRANSLATE); }
	  '(' expression_  ',' expression_ ',' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_REPLACE, $4, $6, $8);

		DBG_PRINT}}
	| REPLACE
		{ push_msg(MSGCAT_SYNTAX_INVALID_REPLACE); }
	  '(' expression_  ',' expression_ ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_REPLACE, $4, $6, NULL);

		DBG_PRINT}}
	| STR_TO_DATE
		{ push_msg(MSGCAT_SYNTAX_INVALID_STRTODATE); }
	  '(' expression_  ',' char_string_literal ')'
		{ pop_msg(); }
		{{

			$$ = parser_make_expression (PT_STR_TO_DATE, $4, $6, NULL);

		DBG_PRINT}}
	| STR_TO_DATE
		{ push_msg(MSGCAT_SYNTAX_INVALID_STRTODATE); }
	  '(' expression_  ',' Null ')'
		{ pop_msg(); }
		{{
			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			if (node)
			  node->type_enum = PT_TYPE_NULL;

			$$ = parser_make_expression (PT_STR_TO_DATE, $4, node, NULL);

		DBG_PRINT}}
	;


of_dates
	: SYS_DATE
	| CURRENT_DATE
	| CURRENT_DATE
		{ push_msg(MSGCAT_SYNTAX_INVALID_CURRENT_DATE); }
	  '(' ')'
		{ pop_msg(); }
	;

of_times
	: SYS_TIME_
	| CURRENT_TIME
	| CURRENT_TIME
		{ push_msg(MSGCAT_SYNTAX_INVALID_CURRENT_TIME); }
	  '(' ')'
		{ pop_msg(); }
	;

of_timestamps
	: SYS_TIMESTAMP
	| CURRENT_TIMESTAMP
	| CURRENT_TIMESTAMP
		{ push_msg(MSGCAT_SYNTAX_INVALID_CURRENT_TIMESTAMP); }
	  '(' ')'
		{ pop_msg(); }
	| LOCALTIME
	| LOCALTIME
		{ push_msg(MSGCAT_SYNTAX_INVALID_LOCALTIME); }
	  '(' ')'
		{ pop_msg(); }
	| LOCALTIMESTAMP
	| LOCALTIMESTAMP
		{ push_msg(MSGCAT_SYNTAX_INVALID_LOCALTIMESTAMP); }
	  '(' ')'
		{ pop_msg(); }
	;

of_datetimes
	: SYS_DATETIME
	| CURRENT_DATETIME
	| CURRENT_DATETIME
		{ push_msg(MSGCAT_SYNTAX_INVALID_CURRENT_DATETIME); }
	  '(' ')'
		{ pop_msg(); }
	;

of_users
	: CURRENT_USER
	| SYSTEM_USER
	| USER
	;

of_avg_max_etc
	: AVG
		{{

			$$ = PT_AVG;

		DBG_PRINT}}
	| Max
		{{

			$$ = PT_MAX;

		DBG_PRINT}}
	| Min
		{{

			$$ = PT_MIN;

		DBG_PRINT}}
	| SUM
		{{

			$$ = PT_SUM;

		DBG_PRINT}}
	| STDDEV
		{{

			$$ = PT_STDDEV;

		DBG_PRINT}}
	| VARIANCE
		{{

			$$ = PT_VARIANCE;

		DBG_PRINT}}
	| BIT_AND
		{{

			$$ = PT_AGG_BIT_AND;

		DBG_PRINT}}
	| BIT_OR
		{{

			$$ = PT_AGG_BIT_OR;

		DBG_PRINT}}
	| BIT_XOR
		{{

			$$ = PT_AGG_BIT_XOR;

		DBG_PRINT}}
	;

of_distinct_unique
	: DISTINCT
	| UNIQUE
	;

of_leading_trailing_both
	: LEADING_
		{{

			$$ = PT_LEADING;

		DBG_PRINT}}
	| TRAILING_
		{{

			$$ = PT_TRAILING;

		DBG_PRINT}}
	| BOTH_
		{{

			$$ = PT_BOTH;

		DBG_PRINT}}
	;

case_expr
	: NULLIF '(' expression_ ',' expression_ ')'
		{{
			$$ = parser_make_expression (PT_NULLIF, $3, $5, NULL);
		DBG_PRINT}}
	| COALESCE '(' expression_list ')'
		{{
			PT_NODE *prev, *expr, *arg, *tmp;
			int count = parser_count_list ($3);
			int i;
			arg = $3;

			expr = parser_new_node (this_parser, PT_EXPR);
			if (expr)
			  {
			    expr->info.expr.op = PT_COALESCE;
			    expr->info.expr.arg1 = arg;
			    expr->info.expr.arg2 = NULL;
			    expr->info.expr.arg3 = NULL;
			    expr->info.expr.continued_case = 1;
			  }

			PICE (expr);
			prev = expr;

			if (count > 1)
			  {
			    tmp = arg;
			    arg = arg->next;
			    tmp->next = NULL;
			    if (prev)
			      prev->info.expr.arg2 = arg;
			    PICE (prev);
			  }
			for (i = 3; i <= count; i++)
			  {
			    tmp = arg;
			    arg = arg->next;
			    tmp->next = NULL;

			    expr = parser_new_node (this_parser, PT_EXPR);
			    if (expr)
			      {
				expr->info.expr.op = PT_COALESCE;
				expr->info.expr.arg1 = prev;
				expr->info.expr.arg2 = arg;
				expr->info.expr.arg3 = NULL;
				expr->info.expr.continued_case = 1;
			      }
			    if (prev && prev->info.expr.continued_case >= 1)
			      prev->info.expr.continued_case++;
			    PICE (expr);
			    prev = expr;
			  }

			if (expr->info.expr.arg2 == NULL)
			  {
			    expr->info.expr.arg2 = parser_new_node (this_parser, PT_VALUE);

			    if (expr->info.expr.arg2)
			      {
				expr->info.expr.arg2->type_enum = PT_TYPE_NULL;
                                expr->info.expr.arg2->is_hidden_column = 1;
			      }
			  }

			$$ = expr;

		DBG_PRINT}}
	| CASE expression_ simple_when_clause_list opt_else_expr END
		{{

			int i;
			PT_NODE *case_oper = $2;
			PT_NODE *node, *prev, *tmp, *curr, *ppp;

			int count = parser_count_list ($3);
			node = prev = $3;
			if (node)
			  node->info.expr.continued_case = 0;

			tmp = $3;
			do
			  {
			    (tmp->info.expr.arg3)->info.expr.arg1 =
			      parser_copy_tree_list (this_parser, case_oper);
			  }
			while ((tmp = tmp->next));

			curr = node;
			for (i = 2; i <= count; i++)
			  {
			    curr = curr->next;
			    if (curr)
			      curr->info.expr.continued_case = 1;
			    if (prev)
			      prev->info.expr.arg2 = curr;	/* else res */
			    PICE (prev);
			    prev->next = NULL;
			    prev = curr;
			  }

			ppp = $4;
			if (prev)
			  prev->info.expr.arg2 = ppp;
			PICE (prev);

			if (prev && !prev->info.expr.arg2)
			  {
			    ppp = parser_new_node (this_parser, PT_VALUE);
			    if (ppp)
			      ppp->type_enum = PT_TYPE_NULL;
			    prev->info.expr.arg2 = ppp;
			    PICE (prev);
			  }

			if (case_oper)
			  parser_free_node (this_parser, case_oper);

			$$ = node;

		DBG_PRINT}}
	| CASE searched_when_clause_list opt_else_expr END
		{{

			int i;
			PT_NODE *node, *prev, *curr, *ppp;

			int count = parser_count_list ($2);
			node = prev = $2;
			if (node)
			  node->info.expr.continued_case = 0;

			curr = node;
			for (i = 2; i <= count; i++)
			  {
			    curr = curr->next;
			    if (curr)
			      curr->info.expr.continued_case = 1;
			    if (prev)
			      prev->info.expr.arg2 = curr;	/* else res */
			    PICE (prev);
			    prev->next = NULL;
			    prev = curr;
			  }

			ppp = $3;
			if (prev)
			  prev->info.expr.arg2 = ppp;
			PICE (prev);

			if (prev && !prev->info.expr.arg2)
			  {
			    ppp = parser_new_node (this_parser, PT_VALUE);
			    if (ppp)
			      ppp->type_enum = PT_TYPE_NULL;
			    prev->info.expr.arg2 = ppp;
			    PICE (prev);
			  }

			$$ = node;

		DBG_PRINT}}
	;

opt_else_expr
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| ELSE expression_
		{{

			$$ = $2;

		DBG_PRINT}}
	;

simple_when_clause_list
	: simple_when_clause_list simple_when_clause
		{{

			$$ = parser_make_link ($1, $2);

		DBG_PRINT}}
	| simple_when_clause
		{{

			$$ = $1;

		DBG_PRINT}}
	;

simple_when_clause
	: WHEN expression_ THEN expression_
		{{

			PT_NODE *node, *ppp, *qqq;
			ppp = $2;
			node = parser_new_node (this_parser, PT_EXPR);
			if (node)
			  {
			    node->info.expr.op = PT_CASE;
			    node->info.expr.qualifier = PT_SIMPLE_CASE;
			    qqq = parser_new_node (this_parser, PT_EXPR);
			    if (qqq)
			      {
				qqq->info.expr.op = PT_EQ;
				qqq->info.expr.arg2 = ppp;
				node->info.expr.arg3 = qqq;
				PICE (qqq);
			      }
			  }

			ppp = $4;
			if (node)
			  node->info.expr.arg1 = ppp;
			PICE (node);

			$$ = node;

		DBG_PRINT}}
	;

searched_when_clause_list
	: searched_when_clause_list searched_when_clause
		{{

			$$ = parser_make_link ($1, $2);

		DBG_PRINT}}
	| searched_when_clause
		{{

			$$ = $1;

		DBG_PRINT}}
	;

searched_when_clause
	: WHEN search_condition THEN expression_
		{{

			PT_NODE *node, *ppp;
			node = parser_new_node (this_parser, PT_EXPR);
			if (node)
			  {
			    node->info.expr.op = PT_CASE;
			    node->info.expr.qualifier = PT_SEARCHED_CASE;
			  }

			ppp = $2;
			if (node)
			  node->info.expr.arg3 = ppp;
			PICE (node);

			ppp = $4;
			if (node)
			  node->info.expr.arg1 = ppp;
			PICE (node);

			$$ = node;

		DBG_PRINT}}
	;


extract_expr
	: EXTRACT '(' datetime_field FROM expression_ ')'
		{{

			PT_NODE *tmp;
			tmp = parser_make_expression (PT_EXTRACT, $5, NULL, NULL);
			if (tmp)
			  tmp->info.expr.qualifier = $3;
			$$ = tmp;

		DBG_PRINT}}
	;

adddate_name
	: DATE_ADD
	| ADDDATE
	;

subdate_name
	: DATE_SUB
	| SUBDATE
	;

datetime_field
	: YEAR_
		{{

			$$ = PT_YEAR;

		DBG_PRINT}}
	| MONTH_
		{{

			$$ = PT_MONTH;

		DBG_PRINT}}
	| DAY_
		{{

			$$ = PT_DAY;

		DBG_PRINT}}
	| HOUR_
		{{

			$$ = PT_HOUR;

		DBG_PRINT}}
	| MINUTE_
		{{

			$$ = PT_MINUTE;

		DBG_PRINT}}
	| SECOND_
		{{

			$$ = PT_SECOND;

		DBG_PRINT}}
	| MILLISECOND_
		{{

			$$ = PT_MILLISECOND;

		DBG_PRINT}}
	| WEEK
		{{

			$$ = PT_WEEK;

		DBG_PRINT}}
	| QUARTER
		{{

			$$ = PT_QUARTER;

    		DBG_PRINT}}
        | SECOND_MILLISECOND
		{{

			$$ = PT_SECOND_MILLISECOND;

    		DBG_PRINT}}
	| MINUTE_MILLISECOND
		{{

			$$ = PT_MINUTE_MILLISECOND;

    		DBG_PRINT}}
	| MINUTE_SECOND
		{{

			$$ = PT_MINUTE_SECOND;

    		DBG_PRINT}}
	| HOUR_MILLISECOND
		{{

			$$ = PT_HOUR_MILLISECOND;

    		DBG_PRINT}}
	| HOUR_SECOND
		{{

			$$ = PT_HOUR_SECOND;

    		DBG_PRINT}}
	| HOUR_MINUTE
		{{

			$$ = PT_HOUR_MINUTE;

    		DBG_PRINT}}
	| DAY_MILLISECOND
		{{

			$$ = PT_DAY_MILLISECOND;

    		DBG_PRINT}}
	| DAY_SECOND
		{{

			$$ = PT_DAY_SECOND;

    		DBG_PRINT}}
	| DAY_MINUTE
		{{

			$$ = PT_DAY_MINUTE;

    		DBG_PRINT}}
	| DAY_HOUR
		{{

			$$ = PT_DAY_HOUR;

    		DBG_PRINT}}
	| YEAR_MONTH
		{{

			$$ = PT_YEAR_MONTH;

    		DBG_PRINT}}
	;

opt_on_target
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| ON_ primary
		{{

			$$ = $2;

		DBG_PRINT}}
	;

generic_function
	: identifier '(' opt_expression_list ')' opt_on_target
		{{

			PT_NODE *node = NULL;
			if ($5 == NULL)
			  node = keyword_func ($1->info.name.original, $3);

			if (node == NULL)
			  {
			    node = parser_new_node (this_parser, PT_METHOD_CALL);

			    if (node)
			      {
				node->info.method_call.method_name = $1;
				node->info.method_call.arg_list = $3;
				node->info.method_call.on_call_target = $5;
				node->info.method_call.call_or_expr = PT_IS_MTHD_EXPR;
			      }
			  }

			$$ = node;

		DBG_PRINT}}
	;

generic_function_id
	: generic_function
		{{

			PT_NODE *node = $1;

			if (node->node_type == PT_METHOD_CALL)
			  {
			    if (node && !node->info.method_call.on_call_target)
			      {
				const char *callee;
				PT_NODE *name = node->info.method_call.method_name;
				PT_NODE *args = node->info.method_call.arg_list;

				node->node_type = PT_FUNCTION;

				node->info.function.arg_list = args;
				node->info.function.function_type = PT_GENERIC;

				callee = (name ? name->info.name.original : "");
				node->info.function.generic_name = callee;
			      }

			    parser_cannot_prepare = true;
			    parser_cannot_cache = true;
			  }

			$$ = node;

		DBG_PRINT}}
	;

opt_expression_list
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| expression_list
		{{

			$$ = $1;

		DBG_PRINT}}
	;

table_set_function_call
	: SET subquery
		{{

			PT_NODE *func_node;
			func_node = parser_new_node (this_parser, PT_FUNCTION);
			if (func_node)
			  {
			    func_node->info.function.arg_list = $2;
			    func_node->info.function.function_type = F_TABLE_SET;
			  }
			$$ = func_node;

		DBG_PRINT}}
	| SEQUENCE subquery
		{{

			PT_NODE *func_node;
			func_node = parser_new_node (this_parser, PT_FUNCTION);
			if (func_node)
			  {
			    func_node->info.function.arg_list = $2;
			    func_node->info.function.function_type = F_TABLE_SEQUENCE;
			  }
			$$ = func_node;

		DBG_PRINT}}
	| LIST subquery
		{{

			PT_NODE *func_node;
			func_node = parser_new_node (this_parser, PT_FUNCTION);
			if (func_node)
			  {
			    func_node->info.function.arg_list = $2;
			    func_node->info.function.function_type = F_TABLE_SEQUENCE;
			  }
			$$ = func_node;

		DBG_PRINT}}
	| MULTISET subquery
		{{

			PT_NODE *func_node;
			func_node = parser_new_node (this_parser, PT_FUNCTION);
			if (func_node)
			  {
			    func_node->info.function.arg_list = $2;
			    func_node->info.function.function_type = F_TABLE_MULTISET;
			  }
			$$ = func_node;

		DBG_PRINT}}
	;

search_condition
	: search_condition OR boolean_term_xor
		{{

			$$ = parser_make_expression (PT_OR, $1, $3, NULL);

		DBG_PRINT}}
	| boolean_term_xor
		{{

			$$ = $1;

		DBG_PRINT}}
	;

boolean_term_xor
	: boolean_term_xor XOR boolean_term_is
		{{

			$$ = parser_make_expression (PT_XOR, $1, $3, NULL);

		DBG_PRINT}}
	| boolean_term_is
		{{

			$$ = $1;
		DBG_PRINT}}
	;

boolean_term_is
	: boolean_term_is is_op boolean
		{{

			$$ = parser_make_expression ($2, $1, $3, NULL);

		DBG_PRINT}}
	| boolean_term
		{{

			$$ = $1;

		DBG_PRINT}}
	;

is_op
	: IS NOT
		{{

			$$ = PT_IS_NOT;

		DBG_PRINT}}
	| IS
		{{

			$$ = PT_IS;

		DBG_PRINT}}
	;

boolean_term
	: boolean_term AND boolean_factor
		{{

			$$ = parser_make_expression (PT_AND, $1, $3, NULL);

		DBG_PRINT}}
	| boolean_factor
		{{

			$$ = $1;

		DBG_PRINT}}
	;

boolean_factor
	: NOT predicate
		{{

			$$ = parser_make_expression (PT_NOT, $2, NULL, NULL);

		DBG_PRINT}}
	| '!' predicate
		{{

			$$ = parser_make_expression (PT_NOT, $2, NULL, NULL);

		DBG_PRINT}}
	| predicate
		{{

			$$ = $1;

		DBG_PRINT}}
	;

predicate
	: EXISTS expression_
		{{

			$$ = parser_make_expression (PT_EXISTS, $2, NULL, NULL);

		DBG_PRINT}}
	| expression_
		{{

			$$ = $1;

		DBG_PRINT}}
	| predicate_expression
		{{

			$$ = $1;

		DBG_PRINT}}
	;

predicate_expression
	: predicate_expr_sub
		{{

			PT_JOIN_TYPE join_type = parser_top_join_type ();
			if (join_type == PT_JOIN_RIGHT_OUTER)
			  parser_restore_wjc ();

		DBG_PRINT}}
	  opt_paren_plus
		{{

			PT_JOIN_TYPE join_type = parser_pop_join_type ();
			PT_NODE *e, *attr;

			if ($3)
			  {
			    if (join_type == PT_JOIN_RIGHT_OUTER)
			      join_type = PT_JOIN_FULL_OUTER;
			    else
			      join_type = PT_JOIN_LEFT_OUTER;
			  }

			/*
			 * marking Oracle style left/right outer join operator
			 *
			 * Oracle style outer join support: convert to ANSI standard style
			 * only permit the following predicate
			 *
			 * 'single_column(+) op expression_'
			 * 'expression_   op single_column(+)'
			 */

			e = $1;

			if (join_type != PT_JOIN_NONE)
			  {
			    if (e && e->node_type == PT_EXPR)
			      {
				switch (join_type)
				  {
				  case PT_JOIN_LEFT_OUTER:
				    attr = e->info.expr.arg2;
				    break;
				  case PT_JOIN_RIGHT_OUTER:
				    attr = e->info.expr.arg1;
				    break;
				  case PT_JOIN_FULL_OUTER:
				    PT_ERROR (this_parser, e,
					      "a predicate may reference only one outer-joined table");
				    attr = NULL;
				    break;
				  default:
				    PT_ERROR (this_parser, e, "check syntax at '(+)'");
				    attr = NULL;
				    break;
				  }

				if (attr)
				  {
				    while (attr->node_type == PT_DOT_)
				      attr = attr->info.dot.arg2;

				    if (attr->node_type == PT_NAME)
				      {
					switch (join_type)
					  {
					  case PT_JOIN_LEFT_OUTER:
					    PT_EXPR_INFO_SET_FLAG (e, PT_EXPR_INFO_LEFT_OUTER);
					    parser_found_Oracle_outer = true;
					    break;
					  case PT_JOIN_RIGHT_OUTER:
					    PT_EXPR_INFO_SET_FLAG (e, PT_EXPR_INFO_RIGHT_OUTER);
					    parser_found_Oracle_outer = true;
					    break;
					  default:
					    break;
					  }
				      }
				    else
				      {
					PT_ERROR (this_parser, e,
						  "'(+)' operator can be applied only to a column, not to an arbitary expression");
				      }
				  }
			      }
			  }				/* if (join_type != PT_JOIN_INNER) */

			$$ = e;

		DBG_PRINT}}
	;


predicate_expr_sub
	: pred_lhs comp_op expression_
		{{

			PT_NODE *e, *opd1, *opd2, *subq;
			PT_OP_TYPE op;
			bool found_paren_set_expr = false;

			opd2 = $3;
			e = parser_make_expression ($2, $1, NULL, NULL);

			if (e && this_parser->error_msgs == NULL)
			  {

			    e->info.expr.arg2 = opd2;
			    opd1 = e->info.expr.arg1;
			    op = e->info.expr.op;

			    /* convert parentheses set expr value into sequence */
			    if (opd1)
			      {
				if (opd1->node_type == PT_VALUE &&
				    opd1->type_enum == PT_TYPE_EXPR_SET)
				  {
				    opd1->type_enum = PT_TYPE_SEQUENCE;
				    found_paren_set_expr = true;
				  }
				else if (PT_IS_QUERY_NODE_TYPE (opd1->node_type))
				  {
				    if ((subq = pt_get_subquery_list (opd1)) && subq->next == NULL)
				      {
					/* single-column subquery */
				      }
				    else
				      {
					found_paren_set_expr = true;
				      }
				  }
			      }
			    if (opd2)
			      {
				if (opd2->node_type == PT_VALUE &&
				    opd2->type_enum == PT_TYPE_EXPR_SET)
				  {
				    opd2->type_enum = PT_TYPE_SEQUENCE;
				    found_paren_set_expr = true;
				  }
				else if (PT_IS_QUERY_NODE_TYPE (opd2->node_type))
				  {
				    if ((subq = pt_get_subquery_list (opd2)) && subq->next == NULL)
				      {
					/* single-column subquery */
				      }
				    else
				      {
					found_paren_set_expr = true;
				      }
				  }
			      }
			    if (op == PT_EQ || op == PT_NE)
			      {
				/* expression number check */
				if (found_paren_set_expr == true &&
				    pt_check_set_count_set (this_parser, opd1, opd2))
				  {
				    if (PT_IS_QUERY_NODE_TYPE (opd1->node_type))
				      {
					pt_select_list_to_one_col (this_parser, opd1, true);
				      }
				    if (PT_IS_QUERY_NODE_TYPE (opd2->node_type))
				      {
					pt_select_list_to_one_col (this_parser, opd2, true);
				      }
				    /* rewrite parentheses set expr equi-comparions predicate
				     * as equi-comparison predicates tree of each elements.
				     * for example, (a, b) = (x, y) -> a = x and b = y
				     */
				    if (op == PT_EQ && pt_is_set_type (opd1) && pt_is_set_type (opd2))
				      {
					e = pt_rewrite_set_eq_set (this_parser, e);
				      }
				  }
				/* mark as single tuple list */
				if (PT_IS_QUERY_NODE_TYPE (opd1->node_type))
				  {
				    opd1->info.query.single_tuple = 1;
				  }
				if (PT_IS_QUERY_NODE_TYPE (opd2->node_type))
				  {
				    opd2->info.query.single_tuple = 1;
				  }
			      }
			    else
			      {
				if (found_paren_set_expr == true)
				  {			/* operator check */
				    PT_ERRORf (this_parser, e,
					       "check syntax at %s, illegal operator.",
					       pt_show_binopcode (op));
				  }
			      }
			  }				/* if (e) */
			PICE (e);

			$$ = e;

		DBG_PRINT}}
	| pred_lhs like_op expression_ ESCAPE escape_string_literal
		{{

			PT_NODE *esc = parser_make_expression (PT_LIKE_ESCAPE, $3, $5, NULL);
			PT_NODE *node = parser_make_expression ($2, $1, esc, NULL);
			$$ = node;

		DBG_PRINT}}
	| pred_lhs like_op expression_
		{{

			$$ = parser_make_expression ($2, $1, $3, NULL);

		DBG_PRINT}}
	| pred_lhs null_op
		{{

			$$ = parser_make_expression ($2, $1, NULL, NULL);

		DBG_PRINT}}
	| pred_lhs set_op expression_
		{{

			$$ = parser_make_expression ($2, $1, $3, NULL);

		DBG_PRINT}}
	| pred_lhs between_op expression_ AND expression_
		{{

			PT_NODE *node = parser_make_expression (PT_BETWEEN_AND, $3, $5, NULL);
			$$ = parser_make_expression ($2, $1, node, NULL);

		DBG_PRINT}}
	| pred_lhs in_op in_pred_operand
		{{

			PT_NODE *node = parser_make_expression ($2, $1, NULL, NULL);
			PT_NODE *t = CONTAINER_AT_1 ($3);
			bool is_paren = (bool)TO_NUMBER (CONTAINER_AT_0 ($3));
			int lhs_cnt, rhs_cnt = 0;
			PT_NODE *v, *lhs, *rhs, *subq;
			bool found_match = false;
			bool found_paren_set_expr = false;

			if (node)
			  {
			    lhs = node->info.expr.arg1;
			    /* convert lhs parentheses set expr value into
			     * sequence value */
			    if (lhs)
			      {
				if (lhs->node_type == PT_VALUE && lhs->type_enum == PT_TYPE_EXPR_SET)
				  {
				    lhs->type_enum = PT_TYPE_SEQUENCE;
				    found_paren_set_expr = true;
				  }
				else if (PT_IS_QUERY_NODE_TYPE (lhs->node_type))
				  {
				    if ((subq = pt_get_subquery_list (lhs)) && subq->next == NULL)
				      {
					/* single column subquery */
				      }
				    else
				      {
					found_paren_set_expr = true;
				      }
				  }
			      }

			    if (is_paren == true)
			      {				/* convert to multi-set */
				v = parser_new_node (this_parser, PT_VALUE);
				if (v)
				  {
				    v->info.value.data_value.set = t;
				    v->type_enum = PT_TYPE_MULTISET;
				  }			/* if (v) */
				node->info.expr.arg2 = v;
			      }
			    else
			      {
				/* convert subquery-starting parentheses set expr
				 * ( i.e., {subquery, x, y, ...} ) into multi-set */
				if (t->node_type == PT_VALUE && t->type_enum == PT_TYPE_EXPR_SET)
				  {
				    is_paren = true;	/* mark as parentheses set expr */
				    t->type_enum = PT_TYPE_MULTISET;
				  }
				node->info.expr.arg2 = t;
			      }

			    rhs = node->info.expr.arg2;
			    if (is_paren == true)
			      {
				rhs = rhs->info.value.data_value.set;
			      }


			    /* for each rhs elements, convert parentheses
			     * set expr value into sequence value */
			    for (t = rhs; t; t = t->next)
			      {
				if (t->node_type == PT_VALUE && t->type_enum == PT_TYPE_EXPR_SET)
				  {
				    t->type_enum = PT_TYPE_SEQUENCE;
				    found_paren_set_expr = true;
				  }
				else if (PT_IS_QUERY_NODE_TYPE (t->node_type))
				  {
				    if ((subq = pt_get_subquery_list (t)) && subq->next == NULL)
				      {
					/* single column subquery */
				      }
				    else
				      {
					found_paren_set_expr = true;
				      }
				  }
			      }

			    if (found_paren_set_expr == true)
			      {
				/* expression number check */
				if ((lhs_cnt = pt_get_expression_count (lhs)) < 0)
				  {
				    found_match = true;
				  }
				else
				  {
				    for (t = rhs; t; t = t->next)
				      {
					rhs_cnt = pt_get_expression_count (t);
					if ((rhs_cnt < 0) || (lhs_cnt == rhs_cnt))
					  {
					    /* can not check negative rhs_cnt. go ahead */
					    found_match = true;
					    break;
					  }
				      }
				  }

				if (found_match == true)
				  {
				    /* convert select list of parentheses set expr
				     * into that of sequence value */
				    if (pt_is_query (lhs))
				      {
					pt_select_list_to_one_col (this_parser, lhs, true);
				      }
				    for (t = rhs; t; t = t->next)
				      {
					if (pt_is_query (t))
					  {
					    pt_select_list_to_one_col (this_parser, t, true);
					  }
				      }
				  }
				else
				  {
				    PT_ERRORmf2 (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
						 MSGCAT_SEMANTIC_ATT_CNT_COL_CNT_NE,
						 lhs_cnt, rhs_cnt);
				  }
			      }
			  }

			$$ = node;

		DBG_PRINT}}
	;
	| pred_lhs RANGE_ '(' range_list ')'
		{{

			$$ = parser_make_expression (PT_RANGE, $1, $4, NULL);

		DBG_PRINT}}
	| pred_lhs IdName
		{{

			push_msg (MSGCAT_SYNTAX_INVALID_RELATIONAL_OP);
			csql_yyerror_explicit (@2.first_line, @2.first_column);

		DBG_PRINT}}
	;

pred_lhs
	: expression_ opt_paren_plus
		{{

			PT_JOIN_TYPE join_type = PT_JOIN_NONE;

			if ($2)
			  {
			    join_type = PT_JOIN_RIGHT_OUTER;
			    parser_save_and_set_wjc (1);
			  }
			parser_push_join_type (join_type);

			$$ = $1;

		DBG_PRINT}}
	;

opt_paren_plus
	: /* empty */
		{{

			$$ = 0;

		DBG_PRINT}}
	| paren_plus
		{{

			$$ = 1;

		DBG_PRINT}}
	;

comp_op
	:  '=' opt_of_all_some_any
		{{

			switch ($2)
			  {
			  case 0:
			    $$ = PT_EQ;
			    break;
			  case 1:
			    $$ = PT_EQ_ALL;
			    break;
			  case 2:
			    $$ = PT_EQ_SOME;
			    break;
			  case 3:
			    $$ = PT_EQ_SOME;
			    break;
			  }

		DBG_PRINT}}
	| COMP_NOT_EQ opt_of_all_some_any
		{{

			switch ($2)
			  {
			  case 0:
			    $$ = PT_NE;
			    break;
			  case 1:
			    $$ = PT_NE_ALL;
			    break;
			  case 2:
			    $$ = PT_NE_SOME;
			    break;
			  case 3:
			    $$ = PT_NE_SOME;
			    break;
			  }

		DBG_PRINT}}
	| '>' opt_of_all_some_any
		{{

			switch ($2)
			  {
			  case 0:
			    $$ = PT_GT;
			    break;
			  case 1:
			    $$ = PT_GT_ALL;
			    break;
			  case 2:
			    $$ = PT_GT_SOME;
			    break;
			  case 3:
			    $$ = PT_GT_SOME;
			    break;
			  }

		DBG_PRINT}}
	| COMP_GE opt_of_all_some_any
		{{

			switch ($2)
			  {
			  case 0:
			    $$ = PT_GE;
			    break;
			  case 1:
			    $$ = PT_GE_ALL;
			    break;
			  case 2:
			    $$ = PT_GE_SOME;
			    break;
			  case 3:
			    $$ = PT_GE_SOME;
			    break;
			  }

		DBG_PRINT}}
	| '<'  opt_of_all_some_any
		{{

			switch ($2)
			  {
			  case 0:
			    $$ = PT_LT;
			    break;
			  case 1:
			    $$ = PT_LT_ALL;
			    break;
			  case 2:
			    $$ = PT_LT_SOME;
			    break;
			  case 3:
			    $$ = PT_LT_SOME;
			    break;
			  }

		DBG_PRINT}}
	| COMP_LE opt_of_all_some_any
		{{

			switch ($2)
			  {
			  case 0:
			    $$ = PT_LE;
			    break;
			  case 1:
			    $$ = PT_LE_ALL;
			    break;
			  case 2:
			    $$ = PT_LE_SOME;
			    break;
			  case 3:
			    $$ = PT_LE_SOME;
			    break;
			  }

		DBG_PRINT}}
	| '=''=' opt_of_all_some_any
		{{

			push_msg (MSGCAT_SYNTAX_INVALID_EQUAL_OP);
			csql_yyerror_explicit (@1.first_line, @1.first_column);

		DBG_PRINT}}
	| '!''=' opt_of_all_some_any
		{{

			push_msg (MSGCAT_SYNTAX_INVALID_NOT_EQUAL);
			csql_yyerror_explicit (@1.first_line, @1.first_column);

		DBG_PRINT}}
	| COMP_NULLSAFE_EQ opt_of_all_some_any
		{{

			$$ = PT_NULLSAFE_EQ;

		DBG_PRINT}}
	;

opt_of_all_some_any
	: /* empty */
		{{

			$$ = 0;

		DBG_PRINT}}
	| ALL
		{{

			$$ = 1;

		DBG_PRINT}}
	| SOME
		{{

			$$ = 2;

		DBG_PRINT}}
	| ANY
		{{

			$$ = 3;

		DBG_PRINT}}
	;

like_op
	: NOT LIKE
		{{

			$$ = PT_NOT_LIKE;

		DBG_PRINT}}
	| LIKE
		{{

			$$ = PT_LIKE;

		DBG_PRINT}}
	;

null_op
	: IS NOT Null
		{{

			$$ = PT_IS_NOT_NULL;

		DBG_PRINT}}
	| IS Null
		{{

			$$ = PT_IS_NULL;

		DBG_PRINT}}
	;


between_op
	: NOT BETWEEN
		{{

			$$ = PT_NOT_BETWEEN;

		DBG_PRINT}}
	| BETWEEN
		{{

			$$ = PT_BETWEEN;

		DBG_PRINT}}
	;

in_op
	: IN_
		{{

			$$ = PT_IS_IN;

		DBG_PRINT}}
	| NOT IN_
		{{

			$$ = PT_IS_NOT_IN;

		DBG_PRINT}}
	;

in_pred_operand
	: expression_
		{{
			container_2 ctn;
			PT_NODE *node = $1;
			PT_NODE *exp = NULL;
			bool is_single_expression = true;

			if (node != NULL)
			  {
			    if (node->node_type == PT_VALUE
				&& node->type_enum == PT_TYPE_EXPR_SET)
			      {
				exp = node->info.value.data_value.set;
				node->info.value.data_value.set = NULL;
				parser_free_node (this_parser, node);
			      }
			    else
			      {
				exp = node;
			      }
			  }

			if (exp && exp->next != NULL)
			  {
			    is_single_expression = false;
			  }

			if (is_single_expression && exp && exp->is_paren == 0)
			  {
			    SET_CONTAINER_2 (ctn, FROM_NUMBER (0), exp);
			  }
			else
			  {
			    SET_CONTAINER_2 (ctn, FROM_NUMBER (1), exp);
			  }

			$$ = ctn;
		DBG_PRINT}}
	;

range_list
	: range_list OR range_
		{{

			$$ = parser_make_link_or ($1, $3);

		DBG_PRINT}}
	| range_
		{{

			$$ = $1;

		DBG_PRINT}}
	;

range_
	: expression_ GE_LE_ expression_
		{{

			$$ = parser_make_expression (PT_BETWEEN_GE_LE, $1, $3, NULL);

		DBG_PRINT}}
	| expression_ GE_LT_ expression_
		{{

			$$ = parser_make_expression (PT_BETWEEN_GE_LT, $1, $3, NULL);

		DBG_PRINT}}
	| expression_ GT_LE_ expression_
		{{

			$$ = parser_make_expression (PT_BETWEEN_GT_LE, $1, $3, NULL);

		DBG_PRINT}}
	| expression_ GT_LT_ expression_
		{{

			$$ = parser_make_expression (PT_BETWEEN_GT_LT, $1, $3, NULL);

		DBG_PRINT}}
	| expression_ '='
		{{

			$$ = parser_make_expression (PT_BETWEEN_EQ_NA, $1, NULL, NULL);

		DBG_PRINT}}
	| expression_ GE_INF_ Max
		{{

			$$ = parser_make_expression (PT_BETWEEN_GE_INF, $1, NULL, NULL);

		DBG_PRINT}}
	| expression_ GT_INF_ Max
		{{

			$$ = parser_make_expression (PT_BETWEEN_GT_INF, $1, NULL, NULL);

		DBG_PRINT}}
	| Min INF_LE_ expression_
		{{

			$$ = parser_make_expression (PT_BETWEEN_INF_LE, $3, NULL, NULL);

		DBG_PRINT}}
	| Min INF_LT_ expression_
		{{

			$$ = parser_make_expression (PT_BETWEEN_INF_LT, $3, NULL, NULL);

		DBG_PRINT}}
	;

set_op
	: SETEQ
		{{

			$$ = PT_SETEQ;

		DBG_PRINT}}
	| SETNEQ
		{{

			$$ = PT_SETNEQ;

		DBG_PRINT}}
	| SUBSET
		{{

			$$ = PT_SUBSET;

		DBG_PRINT}}
	| SUBSETEQ
		{{

			$$ = PT_SUBSETEQ;

		DBG_PRINT}}
	| SUPERSETEQ
		{{

			$$ = PT_SUPERSETEQ;

		DBG_PRINT}}
	| SUPERSET
		{{

			$$ = PT_SUPERSET;

		DBG_PRINT}}
	;

subquery
	: '(' csql_query ')'
		{{

			PT_NODE *stmt = $2;

			if (parser_within_join_condition)
			  {
			    PT_ERRORm (this_parser, stmt, MSGCAT_SET_PARSER_SYNTAX,
				       MSGCAT_SYNTAX_JOIN_COND_SUBQ);
			  }

			if (stmt)
			  stmt->info.query.is_subquery = PT_IS_SUBQUERY;
			$$ = stmt;

		DBG_PRINT}}
	;


path_expression
	: path_header '.' IDENTITY		%dprec 5
		{{

			$$ = $1;

		DBG_PRINT}}
	| path_header '.' OBJECT		%dprec 4
		{{

			PT_NODE *node = $1;
			if (node && node->node_type == PT_NAME)
			  {
			    PT_NAME_INFO_SET_FLAG (node, PT_NAME_INFO_EXTERNAL);
			  }

			$$ = node;

		DBG_PRINT}}
	| path_header '.' '*'			%dprec 3
		{{

			PT_NODE *node = $1;
			if (node && node->node_type == PT_NAME &&
			    node->info.name.meta_class == PT_META_CLASS)
			  {
			    /* don't allow "class class_variable.*" */
			    PT_ERROR (this_parser, node, "check syntax at '*'");
			  }
			else
			  {
			    if (node)
			      node->type_enum = PT_TYPE_STAR;
			  }

			$$ = node;

		DBG_PRINT}}
	| path_id_list				%dprec 2
		{{

			PT_NODE *dot;
			PT_NODE *serial_value = NULL;

			dot = $1;
			if (dot
			    && dot->node_type == PT_DOT_
			    && dot->info.dot.arg2 && dot->info.dot.arg2->node_type == PT_NAME)
			  {
			    PT_NODE *name = dot->info.dot.arg2;
			    PT_NODE *name_str = NULL;
			    unsigned long save_custom;

			    if (intl_mbs_casecmp (name->info.name.original, "current_value") == 0 ||
				intl_mbs_casecmp (name->info.name.original, "currval") == 0)
			      {
				serial_value = parser_new_node (this_parser, PT_EXPR);
				serial_value->info.expr.op = PT_CURRENT_VALUE;
				name_str = parser_new_node (this_parser, PT_VALUE);

				save_custom = this_parser->custom_print;
				this_parser->custom_print |= PT_SUPPRESS_QUOTES;

				name_str->info.value.data_value.str =
				  pt_print_bytes (this_parser, dot->info.dot.arg1);
				this_parser->custom_print = save_custom;

				name_str->info.value.data_value.str->length =
				  strlen ((char *) name_str->info.value.data_value.str->bytes);
				name_str->info.value.text = (char *)
				  name_str->info.value.data_value.str->bytes;
				name_str->type_enum = PT_TYPE_CHAR;
				name_str->info.value.string_type = ' ';
				serial_value->info.expr.arg1 = name_str;
				serial_value->info.expr.arg2 = NULL;
				PICE (serial_value);
				if (parser_serial_check == 0)
				    PT_ERRORmf(this_parser, serial_value,
					MSGCAT_SET_PARSER_SEMANTIC,
					MSGCAT_SEMANTIC_NOT_ALLOWED_HERE,
					"serial");
				parser_free_node (this_parser, dot);
				dot = serial_value;

				parser_cannot_prepare = true;
				parser_cannot_cache = true;
			      }
			    else
			      if (intl_mbs_casecmp (name->info.name.original, "next_value") == 0 ||
				  intl_mbs_casecmp (name->info.name.original, "nextval") == 0)
			      {
				serial_value = parser_new_node (this_parser, PT_EXPR);
				serial_value->info.expr.op = PT_NEXT_VALUE;
				name_str = parser_new_node (this_parser, PT_VALUE);

				save_custom = this_parser->custom_print;
				this_parser->custom_print |= PT_SUPPRESS_QUOTES;

				name_str->info.value.data_value.str =
				  pt_print_bytes (this_parser, dot->info.dot.arg1);
				this_parser->custom_print = save_custom;

				name_str->info.value.data_value.str->length =
				  strlen ((char *) name_str->info.value.data_value.str->bytes);
				name_str->info.value.text = (char *)
				  name_str->info.value.data_value.str->bytes;
				name_str->type_enum = PT_TYPE_CHAR;
				name_str->info.value.string_type = ' ';
				serial_value->info.expr.arg1 = name_str;
				serial_value->info.expr.arg2 = NULL;
				PICE (serial_value);
				if (parser_serial_check == 0)
				    PT_ERRORmf(this_parser, serial_value,
					MSGCAT_SET_PARSER_SEMANTIC,
					MSGCAT_SEMANTIC_NOT_ALLOWED_HERE,
					"serial");
				parser_free_node (this_parser, dot);
				dot = serial_value;

				parser_cannot_prepare = true;
				parser_cannot_cache = true;
			      }
			  }

			$$ = dot;

		DBG_PRINT}}
	;

path_id_list
	: path_id_list path_dot path_id			%dprec 1
		{{

			PT_NODE *dot = parser_new_node (this_parser, PT_DOT_);
			if (dot)
			  {
			    dot->info.dot.arg1 = $1;
			    dot->info.dot.arg2 = $3;
			  }

			$$ = dot;

		DBG_PRINT}}
	| path_header					%dprec 2
		{{

			$$ = $1;

		DBG_PRINT}}
	;

path_header
	: param_
		{{

			$$ = $1;

		DBG_PRINT}}
	| CLASS path_id
		{{

			PT_NODE *node = $2;
			if (node)
			  node->info.name.meta_class = PT_META_CLASS;
			$$ = node;

		DBG_PRINT}}
	| path_id
		{{

			PT_NODE *node = $1;
			if (node && node->node_type != PT_EXPR)
			  node->info.name.meta_class = PT_NORMAL;
			$$ = node;

		DBG_PRINT}}
	;

path_dot
	: '.'
	| RIGHT_ARROW
	;

path_id
	: identifier '{' identifier '}'
		{{

			PT_NODE *corr = $3;
			PT_NODE *name = $1;

			if (name)
			  name->info.name.path_correlation = corr;
			$$ = name;

		DBG_PRINT}}
	| identifier
		{{

			$$ = $1;

		DBG_PRINT}}
	| generic_function_id
		{{

			$$ = $1;

		DBG_PRINT}}
	| table_set_function_call
		{{

			$$ = $1;

		DBG_PRINT}}
	;

simple_path_id
	: identifier '.' identifier
		{{

			PT_NODE *dot = parser_new_node (this_parser, PT_DOT_);
			if (dot)
			  {
			    dot->info.dot.arg1 = $1;
			    dot->info.dot.arg2 = $3;
			  }

			$$ = dot;

		DBG_PRINT}}
	| identifier
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_in_out
	: /* empty */
		{{

			$$ = PT_NOPUT;

		DBG_PRINT}}
	| IN_
		{{

			$$ = PT_INPUT;

		DBG_PRINT}}
	| OUT_
		{{

			$$ = PT_OUTPUT;

		DBG_PRINT}}
	| INOUT
		{{

			$$ = PT_INPUTOUTPUT;

		DBG_PRINT}}
	;


data_type
	: nested_set primitive_type
		{{

			container_2 ctn;
			PT_TYPE_ENUM typ, e;
			PT_NODE *dt;

			typ = $1;
			e = TO_NUMBER (CONTAINER_AT_0 ($2));
			dt = CONTAINER_AT_1 ($2);

			if (!dt)
			  {
			    dt = parser_new_node (this_parser, PT_DATA_TYPE);
			    if (dt)
			      {
				dt->type_enum = e;
				dt->data_type = NULL;
			      }
			  }

			SET_CONTAINER_2 (ctn, FROM_NUMBER (typ), dt);
			$$ = ctn;

		DBG_PRINT}}
	| nested_set '(' data_type_list ')'
		{{

			container_2 ctn;
			PT_TYPE_ENUM typ;
			PT_NODE *dt;

			typ = $1;
			dt = $3;

			SET_CONTAINER_2 (ctn, FROM_NUMBER (typ), dt);
			$$ = ctn;

		DBG_PRINT}}
	| nested_set '(' ')'
		{{

			container_2 ctn;
			PT_TYPE_ENUM typ;

			typ = $1;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (typ), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| nested_set set_type
		{{

			container_2 ctn;
			PT_TYPE_ENUM typ;
			PT_NODE *dt;

			typ = $1;
			dt = parser_new_node (this_parser, PT_DATA_TYPE);
			if (dt)
			  {
			    dt->type_enum = $2;
			    dt->data_type = NULL;
			  }

			SET_CONTAINER_2 (ctn, FROM_NUMBER (typ), dt);
			$$ = ctn;

		DBG_PRINT}}
	| set_type
		{{

			container_2 ctn;
			PT_TYPE_ENUM typ;
			typ = $1;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (typ), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| primitive_type
		{{

			$$ = $1;

		DBG_PRINT}}
	;

nested_set
	: nested_set set_type
		{{

			$$ = $1;

		DBG_PRINT}}
	| set_type
		{{

			$$ = $1;

		DBG_PRINT}}
	;

data_type_list
	: data_type_list ',' data_type
		{{

			PT_NODE *dt;
			PT_TYPE_ENUM e;

			e = TO_NUMBER (CONTAINER_AT_0 ($3));
			dt = CONTAINER_AT_1 ($3);

			if (!dt)
			  {
			    dt = parser_new_node (this_parser, PT_DATA_TYPE);
			    if (dt)
			      {
				dt->type_enum = e;
				dt->data_type = NULL;
			      }
			  }

			$$ = parser_make_link ($1, dt);

		DBG_PRINT}}
	| data_type
		{{

			PT_NODE *dt;
			PT_TYPE_ENUM e;

			e = TO_NUMBER (CONTAINER_AT_0 ($1));
			dt = CONTAINER_AT_1 ($1);

			if (!dt)
			  {
			    dt = parser_new_node (this_parser, PT_DATA_TYPE);
			    if (dt)
			      {
				dt->type_enum = e;
				dt->data_type = NULL;
			      }
			  }

			$$ = dt;

		DBG_PRINT}}
	;

char_bit_type
	: CHAR_ opt_varying
		{{

			if ($2)
			  $$ = PT_TYPE_VARCHAR;
			else
			  $$ = PT_TYPE_CHAR;

		DBG_PRINT}}
	| VARCHAR
		{{

			$$ = PT_TYPE_VARCHAR;

		DBG_PRINT}}
	| NATIONAL CHAR_ opt_varying
		{{

			if ($3)
			  $$ = PT_TYPE_VARNCHAR;
			else
			  $$ = PT_TYPE_NCHAR;

		DBG_PRINT}}
	| NCHAR	opt_varying
		{{

			if ($2)
			  $$ = PT_TYPE_VARNCHAR;
			else
			  $$ = PT_TYPE_NCHAR;

		DBG_PRINT}}
	| BIT opt_varying
		{{

			if ($2)
			  $$ = PT_TYPE_VARBIT;
			else
			  $$ = PT_TYPE_BIT;

		DBG_PRINT}}
	;

opt_varying
	: /* empty */
		{{

			$$ = 0;

		DBG_PRINT}}
	| VARYING
		{{

			$$ = 1;

		DBG_PRINT}}
	;

primitive_type
	: INTEGER
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_INTEGER), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| SmallInt
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_SMALLINT), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| BIGINT
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_BIGINT), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| Double PRECISION
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_DOUBLE), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| Double
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_DOUBLE), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| Date
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_DATE), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| Time
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_TIME), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| Utime
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_TIMESTAMP), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| TIMESTAMP
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_TIMESTAMP), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| DATETIME
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_DATETIME), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| Monetary
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_MONETARY), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| OBJECT
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, FROM_NUMBER (PT_TYPE_OBJECT), NULL);
			$$ = ctn;

		DBG_PRINT}}
	| String
		{{

			container_2 ctn;
			PT_TYPE_ENUM typ = PT_TYPE_VARCHAR;
			PT_NODE *dt = parser_new_node (this_parser, PT_DATA_TYPE);
			if (dt)
			  {
			    dt->type_enum = typ;
			    dt->info.data_type.precision = DB_MAX_VARCHAR_PRECISION;
			  }
			SET_CONTAINER_2 (ctn, FROM_NUMBER (typ), dt);
			$$ = ctn;

		DBG_PRINT}}
	| class_name opt_identity
		{{

			container_2 ctn;
			PT_TYPE_ENUM typ = PT_TYPE_OBJECT;
			PT_NODE *dt = parser_new_node (this_parser, PT_DATA_TYPE);

			if (dt)
			  {
			    dt->type_enum = typ;
			    dt->info.data_type.entity = $1;
			    dt->info.data_type.units = $2;
			  }

			SET_CONTAINER_2 (ctn, FROM_NUMBER (typ), dt);
			$$ = ctn;

		DBG_PRINT}}
	| char_bit_type opt_prec_1
		{{

			container_2 ctn;
			PT_TYPE_ENUM typ = $1;
			PT_NODE *len = NULL, *dt = NULL;
			int l = 1;

			len = $2;

			if (len)
			  {
			    int maxlen = DB_MAX_VARCHAR_PRECISION;
			    l = len->info.value.data_value.i;

			    switch (typ)
			      {
			      case PT_TYPE_CHAR:
				maxlen = DB_MAX_CHAR_PRECISION;
				break;

			      case PT_TYPE_VARCHAR:
				maxlen = DB_MAX_VARCHAR_PRECISION;
				break;

			      case PT_TYPE_NCHAR:
				maxlen = DB_MAX_NCHAR_PRECISION;
				break;

			      case PT_TYPE_VARNCHAR:
				maxlen = DB_MAX_VARNCHAR_PRECISION;
				break;

			      case PT_TYPE_BIT:
				maxlen = DB_MAX_BIT_PRECISION;
				break;

			      case PT_TYPE_VARBIT:
				maxlen = DB_MAX_VARBIT_PRECISION;
				break;

			      default:
				break;
			      }

			    if (l > maxlen)
			      {
				PT_ERRORmf (this_parser, len, MSGCAT_SET_PARSER_SYNTAX,
					    MSGCAT_SYNTAX_MAX_BITLEN, maxlen);
			      }

			    l = (l > maxlen ? maxlen : l);
			  }
			else
			  {
			    switch (typ)
			      {
			      case PT_TYPE_CHAR:
			      case PT_TYPE_NCHAR:
			      case PT_TYPE_BIT:
				l = 1;
				break;

			      case PT_TYPE_VARCHAR:
				l = DB_MAX_VARCHAR_PRECISION;
				break;

			      case PT_TYPE_VARNCHAR:
				l = DB_MAX_VARNCHAR_PRECISION;
				break;

			      case PT_TYPE_VARBIT:
				l = DB_MAX_VARBIT_PRECISION;
				break;

			      default:
				break;
			      }
			  }

			dt = parser_new_node (this_parser, PT_DATA_TYPE);
			if (dt)
			  {
			    dt->type_enum = typ;
			    dt->info.data_type.precision = l;
			    switch (typ)
			      {
			      case PT_TYPE_CHAR:
			      case PT_TYPE_VARCHAR:
				dt->info.data_type.units = INTL_CODESET_ISO88591;
				break;

			      case PT_TYPE_NCHAR:
			      case PT_TYPE_VARNCHAR:
				dt->info.data_type.units = (int) lang_charset ();
				break;

			      case PT_TYPE_BIT:
			      case PT_TYPE_VARBIT:
				dt->info.data_type.units = INTL_CODESET_RAW_BITS;
				break;

			      default:
				break;
			      }
			  }

			SET_CONTAINER_2 (ctn, FROM_NUMBER (typ), dt);
			$$ = ctn;
			if (len)
			  parser_free_node (this_parser, len);

		DBG_PRINT}}
	| NUMERIC opt_prec_2
		{{

			container_2 ctn;
			PT_TYPE_ENUM typ;
			PT_NODE *prec, *scale, *dt;
			prec = CONTAINER_AT_0 ($2);
			scale = CONTAINER_AT_1 ($2);

			dt = parser_new_node (this_parser, PT_DATA_TYPE);
			typ = PT_TYPE_NUMERIC;

			if (dt)
			  {
			    dt->type_enum = typ;
			    dt->info.data_type.precision = prec ? prec->info.value.data_value.i : 15;
			    dt->info.data_type.dec_precision =
			      scale ? scale->info.value.data_value.i : 0;

			    if (scale && prec)
			      if (scale->info.value.data_value.i > prec->info.value.data_value.i)
				{
				  PT_ERRORmf2 (this_parser, dt,
					       MSGCAT_SET_PARSER_SEMANTIC,
					       MSGCAT_SEMANTIC_INV_PREC_SCALE,
					       prec->info.value.data_value.i,
					       scale->info.value.data_value.i);
				}
			    if (prec)
			      if (prec->info.value.data_value.i > DB_MAX_NUMERIC_PRECISION)
				{
				  PT_ERRORmf2 (this_parser, dt,
					       MSGCAT_SET_PARSER_SEMANTIC,
					       MSGCAT_SEMANTIC_PREC_TOO_BIG,
					       prec->info.value.data_value.i,
					       DB_MAX_NUMERIC_PRECISION);
				}
			  }

			SET_CONTAINER_2 (ctn, FROM_NUMBER (typ), dt);
			$$ = ctn;

			if (prec)
			  parser_free_node (this_parser, prec);
			if (scale)
			  parser_free_node (this_parser, scale);

		DBG_PRINT}}
   	| FLOAT_ opt_prec_1
		{{

			container_2 ctn;
			PT_TYPE_ENUM typ;
			PT_NODE *prec, *dt = NULL;
			prec = $2;

			if (prec &&
			    prec->info.value.data_value.i >= 8 &&
			    prec->info.value.data_value.i <= DB_MAX_NUMERIC_PRECISION)
			  {
			    typ = PT_TYPE_DOUBLE;
			  }
			else
			  {
			    dt = parser_new_node (this_parser, PT_DATA_TYPE);
			    typ = PT_TYPE_FLOAT;

			    if (dt)
			      {
				dt->type_enum = typ;
				dt->info.data_type.precision =
				  prec ? prec->info.value.data_value.i : 7;
				dt->info.data_type.dec_precision = 0;

				if (prec)
				  if (prec->info.value.data_value.i > DB_MAX_NUMERIC_PRECISION)
				    {
				      PT_ERRORmf2 (this_parser, dt,
						   MSGCAT_SET_PARSER_SEMANTIC,
						   MSGCAT_SEMANTIC_PREC_TOO_BIG,
						   prec->info.value.data_value.i,
						   DB_MAX_NUMERIC_PRECISION);
				    }
			      }

			  }

			SET_CONTAINER_2 (ctn, FROM_NUMBER (typ), dt);
			$$ = ctn;

			if (prec)
			  parser_free_node (this_parser, prec);

		DBG_PRINT}}
	;

opt_identity
	: /* empty */
		{{

			$$ = 0;

		DBG_PRINT}}
	| IDENTITY
		{{

			$$ = 1;

		DBG_PRINT}}
	;

opt_prec_1
	: /* empty */
		{{

			$$ = NULL;

		DBG_PRINT}}
	| '(' unsigned_integer ')'
		{{

			$$ = $2;

		DBG_PRINT}}
	;


opt_prec_2
	: /* empty */
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, NULL, NULL);
			$$ = ctn;

		DBG_PRINT}}
	| '(' unsigned_integer ')'
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, $2, NULL);
			$$ = ctn;

		DBG_PRINT}}
	| '(' unsigned_integer ',' unsigned_integer ')'
		{{

			container_2 ctn;
			SET_CONTAINER_2 (ctn, $2, $4);
			$$ = ctn;

		DBG_PRINT}}
	;


set_type
	: SET_OF
		{{

			$$ = PT_TYPE_SET;

		DBG_PRINT}}
	| MULTISET_OF
		{{

			$$ = PT_TYPE_MULTISET;

		DBG_PRINT}}
	| SEQUENCE_OF
		{{

			$$ = PT_TYPE_SEQUENCE;

		DBG_PRINT}}
	| of_container opt_of
		{{

			$$ = $1;

		DBG_PRINT}}
	;

opt_of
	: /* empty */
	| OF
	;

signed_literal_
	: literal_
		{{

			$$ = $1;

		DBG_PRINT}}
	| '-' unsigned_integer
		{{

			PT_NODE *node = $2;
			if (node->type_enum == PT_TYPE_BIGINT)
			  {
			    node->info.value.data_value.bigint
			      = -node->info.value.data_value.bigint;
			  }
			else if (node->type_enum == PT_TYPE_NUMERIC)
			  {
			    const char *min_big_int = "9223372036854775808";
			    if ((strlen (node->info.value.text) == 19) &&
			        (strcmp (node->info.value.text, min_big_int) == 0))
			      {
				node->info.value.data_value.bigint = DB_BIGINT_MIN;
				node->type_enum = PT_TYPE_BIGINT;
			      }
			  }
			else
			  {
			    node->info.value.data_value.i = -node->info.value.data_value.i;
			  }

			$$ = node;

		DBG_PRINT}}
	| '-' unsigned_real
		{{

						/* not allowed partition type */
						/* this will cause semantic error */
			$$ = $2;

		DBG_PRINT}}
	| '-' monetary_literal
		{{

						/* not allowed partition type */
						/* this will cause semantic error */
			$$ = $2;

		DBG_PRINT}}
	;

literal_
	: literal_w_o_param
		{{

			$$ = $1;

		DBG_PRINT}}
	| param_
		{{

			$$ = $1;

		DBG_PRINT}}
	;

literal_w_o_param
	: unsigned_integer
		{{

			$$ = $1;

		DBG_PRINT}}
	| unsigned_real
		{{

			$$ = $1;

		DBG_PRINT}}
	| monetary_literal
		{{

			$$ = $1;

		DBG_PRINT}}
	| char_string_literal
		{{

			$$ = $1;

		DBG_PRINT}}
	| bit_string_literal
		{{

			$$ = $1;

		DBG_PRINT}}
	| host_param_input
		{{

			$$ = $1;

		DBG_PRINT}}
	| Null
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			if (node)
			  node->type_enum = PT_TYPE_NULL;
			$$ = node;

		DBG_PRINT}}
	| constant_set
		{{

			$$ = $1;

		DBG_PRINT}}
	| NA
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			if (node)
			  node->type_enum = PT_TYPE_NA;
			$$ = node;

		DBG_PRINT}}
	| date_or_time_literal
		{{

			$$ = $1;

		DBG_PRINT}}
	| boolean
		{{

			$$ = $1;

		DBG_PRINT}}
	;

boolean
	: True
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			if (node)
			  {
			    node->info.value.text = "true";
			    node->info.value.data_value.i = 1;
			    node->type_enum = PT_TYPE_LOGICAL;
			  }
			$$ = node;

		DBG_PRINT}}
	| False
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			if (node)
			  {
			    node->info.value.text = "false";
			    node->info.value.data_value.i = 0;
			    node->type_enum = PT_TYPE_LOGICAL;
			  }
			$$ = node;

		DBG_PRINT}}
	| UNKNOWN
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			if (node)
			  node->type_enum = PT_TYPE_NULL;
			$$ = node;

		DBG_PRINT}}
	;

constant_set
	: opt_of_container '{' expression_list '}'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);
			PT_NODE *e;

			if (node)
			  {
			    node->info.value.data_value.set = $3;
			    node->type_enum = $1;

			    for (e = node->info.value.data_value.set; e; e = e->next)
			      {
				if (e->type_enum == PT_TYPE_STAR)
				  {
				    PT_ERRORf (this_parser, e,
					       "check syntax at %s, illegal '*' expression.",
					       pt_short_print (this_parser, e));

				    break;
				  }
			      }
			  }

			$$ = node;

		DBG_PRINT}}
	| opt_of_container '{' '}'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);

			if (node)
			  {
			    node->info.value.data_value.set = 0;
			    node->type_enum = $1;
			  }

			$$ = node;

		DBG_PRINT}}
	;

opt_of_container
	: /* empty */
		{{

			$$ = PT_TYPE_SEQUENCE;

		DBG_PRINT}}
	| of_container
		{{

			$$ = $1;

		DBG_PRINT}}
	;

of_container
	: SET
		{{

			$$ = PT_TYPE_SET;

		DBG_PRINT}}
	| MULTISET
		{{

			$$ = PT_TYPE_MULTISET;

		DBG_PRINT}}
	| SEQUENCE
		{{

			$$ = PT_TYPE_SEQUENCE;

		DBG_PRINT}}
	| LIST
		{{

			$$ = PT_TYPE_SEQUENCE;

		DBG_PRINT}}
	;

identifier_list
	: identifier_list ',' identifier
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| identifier
		{{

			$$ = $1;

		DBG_PRINT}}
	;


identifier
	: IdName
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| BracketDelimitedIdName
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| BacktickDelimitedIdName
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| DelimitedIdName
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
/*{{{*/
	| ACTIVE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| ANALYZE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| AUTO_INCREMENT
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| CACHE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| COMMITTED
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| COST
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| DECREMENT
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| GE_INF_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| GE_LE_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| GE_LT_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| GROUPS
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| GT_INF_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| GT_LE_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| GT_LT_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| HASH
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| INACTIVE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| INCREMENT
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| INFINITE_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| INF_LE_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| INF_LT_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| INSTANCES
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| INVALIDATE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| JAVA
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| LOCK_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| MAXIMUM
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| MAXVALUE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| MEMBERS
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| MINVALUE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| NAME
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| NOCACHE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| NODE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| NOMAXVALUE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| NOMINVALUE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| PARTITION
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| PARTITIONING
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| PARTITIONS
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| PASSWORD
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| PRINT
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| PRIORITY
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| RANGE_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| REGISTER
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| REJECT_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| REMOVE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| REORGANIZE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| REPEATABLE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| RETAIN
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| REUSE_OID
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| REVERSE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| SCHEMA_SYNC
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| SERIAL
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| STABILITY
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| START_
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| STATEMENT
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| STATUS
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| STDDEV
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| SYSTEM
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| THAN
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| TIMEOUT
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| TRACE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| TRIGGERS
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| UNCOMMITTED
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| UNREGISTER
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| VARIANCE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| WORKSPACE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| ADDDATE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| BIT_AND
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| BIT_OR
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| BIT_XOR
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| DATE_ADD
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| DATE_SUB
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| IFNULL
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| ISNULL
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| LCASE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| QUARTER
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| STR_TO_DATE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| SUBDATE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| UCASE
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
	| WEEK
		{{

			PT_NODE *p = parser_new_node (this_parser, PT_NAME);
			if (p)
			  p->info.name.original = $1;
			$$ = p;

		DBG_PRINT}}
/*}}}*/
	;

escape_string_literal
	: char_string_literal
		{{

			$$ = $1;

		DBG_PRINT}}
	| host_param_input
		{{

			$$ = $1;

		DBG_PRINT}}
        ;


char_string_literal
	: char_string_literal CHAR_STRING
		{{

			PT_NODE *str = $1;
			if (str)
			  {
			    str->info.value.data_value.str =
			      pt_append_bytes (this_parser, str->info.value.data_value.str, $2,
					       strlen ($2));
			    str->info.value.text = (char *) str->info.value.data_value.str->bytes;
			  }

			$$ = str;

		DBG_PRINT}}
	| char_string
		{{

			$$ = $1;

		DBG_PRINT}}
	;

char_string
	: CHAR_STRING
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);

			if (node)
			  {
			    node->type_enum = PT_TYPE_CHAR;
			    node->info.value.string_type = ' ';
			    node->info.value.data_value.str =
			      pt_append_bytes (this_parser, NULL, $1, strlen ($1));
			    node->info.value.text = (char *) node->info.value.data_value.str->bytes;
			  }

			$$ = node;

		DBG_PRINT}}
	| NCHAR_STRING
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);

			if (node)
			  {
			    node->type_enum = PT_TYPE_NCHAR;
			    node->info.value.string_type = 'N';
			    node->info.value.data_value.str =
			      pt_append_bytes (this_parser, NULL, $1, strlen ($1));
			    node->info.value.text = (char *) node->info.value.data_value.str->bytes;
			  }

			$$ = node;

		DBG_PRINT}}
	;


bit_string_literal
	: bit_string_literal CHAR_STRING
		{{

			PT_NODE *str = $1;
			if (str)
			  {
			    str->info.value.data_value.str =
			      pt_append_bytes (this_parser, str->info.value.data_value.str, $2,
					       strlen ($2));
			    str->info.value.text = (char *) str->info.value.data_value.str->bytes;
			  }

			$$ = str;

		DBG_PRINT}}
	| bit_string
		{{

			$$ = $1;

		DBG_PRINT}}
	;

bit_string
	: BIT_STRING
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);

			if (node)
			  {
			    node->type_enum = PT_TYPE_BIT;
			    node->info.value.string_type = 'B';
			    node->info.value.data_value.str =
			      pt_append_bytes (this_parser, NULL, $1, strlen ($1));
			    node->info.value.text = (char *) node->info.value.data_value.str->bytes;
			  }

			$$ = node;

		DBG_PRINT}}
	| HEX_STRING
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_VALUE);

			if (node)
			  {
			    node->type_enum = PT_TYPE_BIT;
			    node->info.value.string_type = 'X';
			    node->info.value.data_value.str =
			      pt_append_bytes (this_parser, NULL, $1, strlen ($1));
			    node->info.value.text = (char *) node->info.value.data_value.str->bytes;
			  }

			$$ = node;

		DBG_PRINT}}
	;

unsigned_integer
	: UNSIGNED_INTEGER
		{{

			PT_NODE *val = parser_new_node (this_parser, PT_VALUE);
			if (val)
			  {
			    val->info.value.text = $1;

			    if ((strlen (val->info.value.text) <= 9) ||
				(strlen (val->info.value.text) == 10 &&
				 (val->info.value.text[0] == '0' || val->info.value.text[0] == '1')))
			      {
				val->info.value.data_value.i = atol ($1);
				val->type_enum = PT_TYPE_INTEGER;
			      }
			    else if ((strlen (val->info.value.text) <= 18) ||
				     (strlen (val->info.value.text) == 19 &&
				      (val->info.value.text[0] >= '0' &&
				       val->info.value.text[0] <= '8')))
			      {
				val->info.value.data_value.bigint = atoll ($1);
				val->type_enum = PT_TYPE_BIGINT;
			      }
			    else
			      {
				const char *max_big_int = "9223372036854775807";

				if ((strlen (val->info.value.text) == 19) &&
				    (strcmp (val->info.value.text, max_big_int) <= 0))
				  {
				    val->info.value.data_value.bigint = atoll ($1);
				    val->type_enum = PT_TYPE_BIGINT;
				  }
				else
				  {
				    val->type_enum = PT_TYPE_NUMERIC;
				  }
			      }
			  }

			$$ = val;

		DBG_PRINT}}
	;

unsigned_int32
	: UNSIGNED_INTEGER
		{{

			PT_NODE *val;
			long int_val;
			char *endptr;

			val = parser_new_node (this_parser, PT_VALUE);
			if (val)
			  {
			    int_val = strtol($1, &endptr, 10);

			    if ((errno == ERANGE
			         && (int_val == LONG_MAX
			             || int_val == LONG_MIN))
				|| (errno != 0 && int_val == 0)
				|| (int_val > INT_MAX))
			      {
				PT_ERRORmf (this_parser, val, MSGCAT_SET_PARSER_SYNTAX,
				            MSGCAT_SYNTAX_INVALID_UNSIGNED_INT32, $1);
			      }

			    val->info.value.data_value.i = int_val;
			    val->type_enum = PT_TYPE_INTEGER;
			  }
			$$ = val;

		DBG_PRINT}}
	;

unsigned_real
	: UNSIGNED_REAL
		{{

			PT_NODE *val = parser_new_node (this_parser, PT_VALUE);
			if (val)
			  {

			    if (strchr ($1, 'E') != NULL || strchr ($1, 'e') != NULL)
			      {

				val->info.value.text = $1;
				val->type_enum = PT_TYPE_DOUBLE;
				val->info.value.data_value.d = atof ($1);
			      }
			    else if (strchr ($1, 'F') != NULL || strchr ($1, 'f') != NULL)
			      {

				val->info.value.text = $1;
				val->type_enum = PT_TYPE_FLOAT;
				val->info.value.data_value.f = (float)atof ($1);
			      }
			    else
			      {
				val->info.value.text = $1;
				val->type_enum = PT_TYPE_NUMERIC;
			      }
			  }

			$$ = val;

		DBG_PRINT}}
	;

monetary_literal
	: DOLLAR_SIGN of_integer_real_literal
		{{

			char *str, *txt;
			PT_NODE *val = parser_new_node (this_parser, PT_VALUE);

			str = pt_append_string (this_parser, NULL, DOLLAR_SIGN_TEXT);
			txt = $2;

			if (val)
			  {
			    val->info.value.data_value.money.type = PT_CURRENCY_DOLLAR;
			    val->info.value.text = pt_append_string (this_parser, str, txt);
			    val->type_enum = PT_TYPE_MONETARY;
			    val->info.value.data_value.money.amount = atof (txt);
			  }

			$$ = val;

		DBG_PRINT}}
	| WON_SIGN of_integer_real_literal
		{{

			char *str, *txt;
			PT_NODE *val = parser_new_node (this_parser, PT_VALUE);

			str = pt_append_string (this_parser, NULL, WON_SIGN_TEXT);
			txt = $2;

			if (val)
			  {
			    val->info.value.data_value.money.type = PT_CURRENCY_WON;
			    val->info.value.text = pt_append_string (this_parser, str, txt);
			    val->type_enum = PT_TYPE_MONETARY;
			    val->info.value.data_value.money.amount = atof (txt);
			  }

			$$ = val;

		DBG_PRINT}}
	| YUAN_SIGN of_integer_real_literal
		{{

			char *str, *txt;
			PT_NODE *val = parser_new_node (this_parser, PT_VALUE);

			str = pt_append_string (this_parser, NULL, YUAN_SIGN_TEXT);
			txt = $2;

			if (val)
			  {
			    val->info.value.data_value.money.type = PT_CURRENCY_YUAN;
			    val->info.value.text = pt_append_string (this_parser, str, txt);
			    val->type_enum = PT_TYPE_MONETARY;
			    val->info.value.data_value.money.amount = atof (txt);
			  }

			$$ = val;

		DBG_PRINT}}
	;

of_integer_real_literal
	: integer_text
		{{

			$$ = $1;

		DBG_PRINT}}
	| opt_plus UNSIGNED_REAL
		{{

			$$ = $2;

		DBG_PRINT}}
	| '-' UNSIGNED_REAL
		{{

			$$ = pt_append_string (this_parser, (char *) "-", $2);

		DBG_PRINT}}
	;

date_or_time_literal
	: Date char_string_literal
		{{

			PT_NODE *val = $2;
			if (val)
			  val->type_enum = PT_TYPE_DATE;
			$$ = val;

		DBG_PRINT}}
	| Time char_string_literal
		{{

			PT_NODE *val = $2;
			if (val)
			  val->type_enum = PT_TYPE_TIME;
			$$ = val;

		DBG_PRINT}}
	| TIMESTAMP char_string_literal
		{{

			PT_NODE *val = $2;
			if (val)
			  val->type_enum = PT_TYPE_TIMESTAMP;
			$$ = val;

		DBG_PRINT}}
	| DATETIME char_string_literal
		{{

			PT_NODE *val = $2;
			if (val)
			  val->type_enum = PT_TYPE_DATETIME;
			$$ = val;

		DBG_PRINT}}
	;

create_as_clause
	: opt_replace AS csql_query
		{{
			container_2 ctn;
			SET_CONTAINER_2(ctn, FROM_NUMBER ($1), $3);
			$$ = ctn;
		DBG_PRINT}}
	;

partition_clause
	: PARTITION opt_by HASH '(' expression_ ')' PARTITIONS unsigned_integer
		{{

			PT_NODE *qc = parser_new_node (this_parser, PT_PARTITION);
			if (qc)
			  {
			    qc->info.partition.expr = $5;
			    qc->info.partition.type = PT_PARTITION_HASH;
			    qc->info.partition.hashsize = $8;
			  }

			$$ = qc;

		DBG_PRINT}}
	| PARTITION opt_by RANGE_ '(' expression_ ')' '(' partition_def_list ')'
		{{

			PT_NODE *qc = parser_new_node (this_parser, PT_PARTITION);
			if (qc)
			  {
			    qc->info.partition.expr = $5;
			    qc->info.partition.type = PT_PARTITION_RANGE;
			    qc->info.partition.parts = $8;
			    qc->info.partition.hashsize = NULL;
			  }

			$$ = qc;

		DBG_PRINT}}
	| PARTITION opt_by LIST '(' expression_ ')' '(' partition_def_list ')'
		{{

			PT_NODE *qc = parser_new_node (this_parser, PT_PARTITION);
			if (qc)
			  {
			    qc->info.partition.expr = $5;
			    qc->info.partition.type = PT_PARTITION_LIST;
			    qc->info.partition.parts = $8;
			    qc->info.partition.hashsize = NULL;
			  }

			$$ = qc;

		DBG_PRINT}}
	;

opt_by
	: /* empty */
	| BY
	;

partition_def_list
	: partition_def_list ',' partition_def
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| partition_def
		{{

			$$ = $1;

		DBG_PRINT}}
	;

partition_def
	: PARTITION identifier VALUES LESS THAN MAXVALUE
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_PARTS);
			if (node)
			  {
			    node->info.parts.name = $2;
			    node->info.parts.type = PT_PARTITION_RANGE;
			    node->info.parts.values = NULL;
			  }

			$$ = node;

		DBG_PRINT}}
	| PARTITION identifier VALUES LESS THAN '(' signed_literal_ ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_PARTS);
			if (node)
			  {
			    node->info.parts.name = $2;
			    node->info.parts.type = PT_PARTITION_RANGE;
			    node->info.parts.values = $7;
			  }

			$$ = node;

		DBG_PRINT}}
	| PARTITION identifier VALUES IN_ '(' signed_literal_list ')'
		{{

			PT_NODE *node = parser_new_node (this_parser, PT_PARTS);
			if (node)
			  {
			    node->info.parts.name = $2;
			    node->info.parts.type = PT_PARTITION_LIST;
			    node->info.parts.values = $6;
			  }

			$$ = node;

		DBG_PRINT}}
	;

alter_partition_clause_for_alter_list
	: partition_clause
		{{

			PT_NODE *alt = parser_get_alter_node ();

			if (alt)
			  {
			    alt->info.alter.code = PT_APPLY_PARTITION;
			    alt->info.alter.alter_clause.partition.info = $1;
			  }

		DBG_PRINT}}
	| REMOVE PARTITIONING
		{{

			PT_NODE *alt = parser_get_alter_node ();

			if (alt)
			  alt->info.alter.code = PT_REMOVE_PARTITION;

		DBG_PRINT}}
	| REORGANIZE PARTITION identifier_list INTO '(' partition_def_list ')'
		{{

			PT_NODE *alt = parser_get_alter_node ();

			if (alt)
			  {
			    alt->info.alter.code = PT_REORG_PARTITION;
			    alt->info.alter.alter_clause.partition.name_list = $3;
			    alt->info.alter.alter_clause.partition.parts = $6;
			  }

		DBG_PRINT}}
	| ANALYZE PARTITION opt_all
		{{

			PT_NODE *alt = parser_get_alter_node ();

			if (alt)
			  {
			    alt->info.alter.code = PT_ANALYZE_PARTITION;
			    alt->info.alter.alter_clause.partition.name_list = NULL;
			  }

		DBG_PRINT}}
	| ANALYZE PARTITION identifier_list
		{{

			PT_NODE *alt = parser_get_alter_node ();

			if (alt)
			  {
			    alt->info.alter.code = PT_ANALYZE_PARTITION;
			    alt->info.alter.alter_clause.partition.name_list = $3;
			  }

		DBG_PRINT}}
	| COALESCE PARTITION unsigned_integer
		{{

			PT_NODE *alt = parser_get_alter_node ();

			if (alt)
			  {
			    alt->info.alter.code = PT_COALESCE_PARTITION;
			    alt->info.alter.alter_clause.partition.size = $3;
			  }

		DBG_PRINT}}
	;

opt_all
	: /* empty */
	| ALL
	;

signed_literal_list
	: signed_literal_list ',' signed_literal_
		{{

			$$ = parser_make_link ($1, $3);

		DBG_PRINT}}
	| signed_literal_
		{{

			$$ = $1;

		DBG_PRINT}}
	;

paren_plus
	: '(' '+' ')'
	;

paren_minus
	: '(' '-' ')'
	;


bad_tokens_for_error_message_only_dont_mind_this_rule
	: '@'
	| ']'
	| '`'
	/*| '^'
	| '&'
	| '~'*/
	;


%%


extern FILE *yyin;

void
_push_msg (int code, int line)
{
  PRINT_2 ("push msg called: %d at line %d\n", code, line);
  g_msg[msg_ptr++] = code;
}

void
pop_msg ()
{
  msg_ptr--;
}


int yyline = 0;
int yycolumn = 0;
int yycolumn_end = 0;

int parser_function_code = PT_EMPTY;

static PT_NODE *
parser_make_expression (PT_OP_TYPE OP, PT_NODE * arg1, PT_NODE * arg2,
			PT_NODE * arg3)
{
  PT_NODE *expr;
  expr = parser_new_node (this_parser, PT_EXPR);
  if (expr)
    {
      expr->info.expr.op = OP;
      expr->info.expr.arg1 = arg1;
      expr->info.expr.arg2 = arg2;
      expr->info.expr.arg3 = arg3;

      if (parser_instnum_check == 1 && !pt_instnum_compatibility (expr))
	{
	  PT_ERRORmf2 (this_parser, expr, MSGCAT_SET_PARSER_SEMANTIC,
		       MSGCAT_SEMANTIC_INSTNUM_COMPATIBILITY_ERR,
		       "INST_NUM() or ROWNUM", "INST_NUM() or ROWNUM");
	}

      if (parser_groupbynum_check == 1 && !pt_groupbynum_compatibility (expr))
	{
	  PT_ERRORmf2 (this_parser, expr, MSGCAT_SET_PARSER_SEMANTIC,
		       MSGCAT_SEMANTIC_INSTNUM_COMPATIBILITY_ERR,
		       "GROUPBY_NUM()", "GROUPBY_NUM()");
	}

      if (parser_orderbynum_check == 1 && !pt_orderbynum_compatibility (expr))
	{
	  PT_ERRORmf2 (this_parser, expr, MSGCAT_SET_PARSER_SEMANTIC,
		       MSGCAT_SEMANTIC_INSTNUM_COMPATIBILITY_ERR,
		       "ORDERBY_NUM()", "ORDERBY_NUM()");
	}

      if (OP == PT_SYS_TIME || OP == PT_SYS_DATE
	  || OP == PT_SYS_DATETIME || OP == PT_SYS_TIMESTAMP)
        {
          parser_si_datetime = true;
	  parser_cannot_cache = true;
	}
    }

  return expr;
}



static PT_NODE *
parser_make_link (PT_NODE * list, PT_NODE * node)
{
  parser_append_node (node, list);
  return list;
}


static PT_NODE *
parser_make_link_or (PT_NODE * list, PT_NODE * node)
{
  parser_append_node_or (node, list);
  return list;
}


static bool parser_cannot_cache_stack_default[STACK_SIZE];
static bool *parser_cannot_cache_stack = parser_cannot_cache_stack_default;
static int parser_cannot_cache_sp = 0;
static int parser_cannot_cache_limit = STACK_SIZE;

static void
parser_save_and_set_cannot_cache (bool value)
{
  if (parser_cannot_cache_sp >= parser_cannot_cache_limit)
    {
      int new_size = parser_cannot_cache_limit * 2 * sizeof(bool);
      bool *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_cannot_cache_stack, parser_cannot_cache_limit);
      if (parser_cannot_cache_stack != parser_cannot_cache_stack_default)
	free (parser_cannot_cache_stack);

      parser_cannot_cache_stack = new_p;
      parser_cannot_cache_limit *= 2;
    }

  parser_cannot_cache_stack[parser_cannot_cache_sp++] = parser_cannot_cache;
  parser_cannot_cache = value;
}

static void
parser_restore_cannot_cache ()
{
  parser_cannot_cache_sp--;
  parser_cannot_cache = parser_cannot_cache_stack[--parser_cannot_cache_sp];
}




static int parser_si_datetime_saved;

static void
parser_save_and_set_si_datetime (int value)
{
  parser_si_datetime_saved = parser_si_datetime;
  parser_si_datetime = value;
}

static void
parser_restore_si_datetime ()
{
  parser_si_datetime = parser_si_datetime_saved;
}



static int parser_si_tran_id_saved;

static void
parser_save_and_set_si_tran_id (int value)
{
  parser_si_tran_id_saved = parser_si_tran_id;
  parser_si_tran_id = value;
}

static void
parser_restore_si_tran_id ()
{
  parser_si_tran_id = parser_si_tran_id_saved;
}



static int parser_cannot_prepare_saved;

static void
parser_save_and_set_cannot_prepare (bool value)
{
  parser_cannot_prepare_saved = parser_cannot_prepare;
  parser_cannot_prepare = value;
}

static void
parser_restore_cannot_prepare ()
{
  parser_cannot_prepare = parser_cannot_prepare_saved;
}



static int parser_wjc_stack_default[STACK_SIZE];
static int *parser_wjc_stack = parser_wjc_stack_default;
static int parser_wjc_sp = 0;
static int parser_wjc_limit = STACK_SIZE;

static void
parser_save_and_set_wjc (int value)
{
  if (parser_wjc_sp >= parser_wjc_limit)
    {
      int new_size = parser_wjc_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_wjc_stack, parser_wjc_limit);
      if (parser_wjc_stack != parser_wjc_stack_default)
	free (parser_wjc_stack);

      parser_wjc_stack = new_p;
      parser_wjc_limit *= 2;
    }

  parser_wjc_stack[parser_wjc_sp++] = parser_within_join_condition;
  parser_within_join_condition = value;
}

static void
parser_restore_wjc ()
{
  parser_within_join_condition = parser_wjc_stack[--parser_wjc_sp];
}



static int parser_instnum_stack_default[STACK_SIZE];
static int *parser_instnum_stack = parser_instnum_stack_default;
static int parser_instnum_sp = 0;
static int parser_instnum_limit = STACK_SIZE;

static void
parser_save_and_set_ic (int value)
{
  if (parser_instnum_sp >= parser_instnum_limit)
    {
      int new_size = parser_instnum_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_instnum_stack, parser_instnum_limit);
      if (parser_instnum_stack != parser_instnum_stack_default)
	free (parser_instnum_stack);

      parser_instnum_stack = new_p;
      parser_instnum_limit *= 2;
    }

  parser_instnum_stack[parser_instnum_sp++] = parser_instnum_check;
  parser_instnum_check = value;
}

static void
parser_restore_ic ()
{
  parser_instnum_check = parser_instnum_stack[--parser_instnum_sp];
}




static int parser_groupbynum_stack_default[STACK_SIZE];
static int *parser_groupbynum_stack = parser_groupbynum_stack_default;
static int parser_groupbynum_sp = 0;
static int parser_groupbynum_limit = STACK_SIZE;

static void
parser_save_and_set_gc (int value)
{
  if (parser_groupbynum_sp >= parser_groupbynum_limit)
    {
      int new_size = parser_groupbynum_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_groupbynum_stack, parser_groupbynum_limit);
      if (parser_groupbynum_stack != parser_groupbynum_stack_default)
	free (parser_groupbynum_stack);

      parser_groupbynum_stack = new_p;
      parser_groupbynum_limit *= 2;
    }

  parser_groupbynum_stack[parser_groupbynum_sp++] = parser_groupbynum_check;
  parser_groupbynum_check = value;
}

static void
parser_restore_gc ()
{
  parser_groupbynum_check = parser_groupbynum_stack[--parser_groupbynum_sp];
}



static int parser_orderbynum_stack_default[STACK_SIZE];
static int *parser_orderbynum_stack = parser_orderbynum_stack_default;
static int parser_orderbynum_sp = 0;
static int parser_orderbynum_limit = STACK_SIZE;

static void
parser_save_and_set_oc (int value)
{
  if (parser_orderbynum_sp >= parser_orderbynum_limit)
    {
      int new_size = parser_orderbynum_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_orderbynum_stack, parser_orderbynum_limit);
      if (parser_orderbynum_stack != parser_orderbynum_stack_default)
	free (parser_orderbynum_stack);

      parser_orderbynum_stack = new_p;
      parser_orderbynum_limit *= 2;
    }

  parser_orderbynum_stack[parser_orderbynum_sp++] = parser_orderbynum_check;
  parser_orderbynum_check = value;
}

static void
parser_restore_oc ()
{
  parser_orderbynum_check = parser_orderbynum_stack[--parser_orderbynum_sp];
}




static int parser_sysc_stack_default[STACK_SIZE];
static int *parser_sysc_stack = parser_sysc_stack_default;
static int parser_sysc_sp = 0;
static int parser_sysc_limit = STACK_SIZE;

static void
parser_save_and_set_sysc (int value)
{
  if (parser_sysc_sp >= parser_sysc_limit)
    {
      int new_size = parser_sysc_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_sysc_stack, parser_sysc_limit);
      if (parser_sysc_stack != parser_sysc_stack_default)
	free (parser_sysc_stack);

      parser_sysc_stack = new_p;
      parser_sysc_limit *= 2;
    }

  parser_sysc_stack[parser_sysc_sp++] = parser_sysconnectbypath_check;
  parser_sysconnectbypath_check = value;
}

static void
parser_restore_sysc ()
{
  parser_sysconnectbypath_check = parser_sysc_stack[--parser_sysc_sp];
}




static int parser_prc_stack_default[STACK_SIZE];
static int *parser_prc_stack = parser_prc_stack_default;
static int parser_prc_sp = 0;
static int parser_prc_limit = STACK_SIZE;

static void
parser_save_and_set_prc (int value)
{
  if (parser_prc_sp >= parser_prc_limit)
    {
      int new_size = parser_prc_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_prc_stack, parser_prc_limit);
      if (parser_prc_stack != parser_prc_stack_default)
	free (parser_prc_stack);

      parser_prc_stack = new_p;
      parser_prc_limit *= 2;
    }

  parser_prc_stack[parser_prc_sp++] = parser_prior_check;
  parser_prior_check = value;
}

static void
parser_restore_prc ()
{
  parser_prior_check = parser_prc_stack[--parser_prc_sp];
}




static int parser_cbrc_stack_default[STACK_SIZE];
static int *parser_cbrc_stack = parser_cbrc_stack_default;
static int parser_cbrc_sp = 0;
static int parser_cbrc_limit = STACK_SIZE;

static void
parser_save_and_set_cbrc (int value)
{
  if (parser_cbrc_sp >= parser_cbrc_limit)
    {
      int new_size = parser_cbrc_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_cbrc_stack, parser_cbrc_limit);
      if (parser_cbrc_stack != parser_cbrc_stack_default)
	free (parser_cbrc_stack);

      parser_cbrc_stack = new_p;
      parser_cbrc_limit *= 2;
    }

  parser_cbrc_stack[parser_cbrc_sp++] = parser_connectbyroot_check;
  parser_connectbyroot_check = value;
}

static void
parser_restore_cbrc ()
{
  parser_connectbyroot_check = parser_cbrc_stack[--parser_cbrc_sp];
}




static int parser_serc_stack_default[STACK_SIZE];
static int *parser_serc_stack = parser_serc_stack_default;
static int parser_serc_sp = 0;
static int parser_serc_limit = STACK_SIZE;

static void
parser_save_and_set_serc (int value)
{
  if (parser_serc_sp >= parser_serc_limit)
    {
      int new_size = parser_serc_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_serc_stack, parser_serc_limit);
      if (parser_serc_stack != parser_serc_stack_default)
	free (parser_serc_stack);

      parser_serc_stack = new_p;
      parser_serc_limit *= 2;
    }

  parser_serc_stack[parser_serc_sp++] = parser_serial_check;
  parser_serial_check = value;
}

static void
parser_restore_serc ()
{
  parser_serial_check = parser_serc_stack[--parser_serc_sp];
}




static int parser_pseudoc_stack_default[STACK_SIZE];
static int *parser_pseudoc_stack = parser_pseudoc_stack_default;
static int parser_pseudoc_sp = 0;
static int parser_pseudoc_limit = STACK_SIZE;

static void
parser_save_and_set_pseudoc (int value)
{
  if (parser_pseudoc_sp >= parser_pseudoc_limit)
    {
      int new_size = parser_pseudoc_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_pseudoc_stack, parser_pseudoc_limit);
      if (parser_pseudoc_stack != parser_pseudoc_stack_default)
	free (parser_pseudoc_stack);

      parser_pseudoc_stack = new_p;
      parser_pseudoc_limit *= 2;
    }

  parser_pseudoc_stack[parser_pseudoc_sp++] = parser_pseudocolumn_check;
  parser_pseudocolumn_check = value;
}

static void
parser_restore_pseudoc ()
{
  parser_pseudocolumn_check = parser_pseudoc_stack[--parser_pseudoc_sp];
}




static int parser_sqc_stack_default[STACK_SIZE];
static int *parser_sqc_stack = parser_sqc_stack_default;
static int parser_sqc_sp = 0;
static int parser_sqc_limit = STACK_SIZE;

static void
parser_save_and_set_sqc (int value)
{
  if (parser_sqc_sp >= parser_sqc_limit)
    {
      int new_size = parser_sqc_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_sqc_stack, parser_sqc_limit);
      if (parser_sqc_stack != parser_sqc_stack_default)
	free (parser_sqc_stack);

      parser_sqc_stack = new_p;
      parser_sqc_limit *= 2;
    }

  parser_sqc_stack[parser_sqc_sp++] = parser_subquery_check;
  parser_subquery_check = value;
}

static void
parser_restore_sqc ()
{
  parser_subquery_check = parser_sqc_stack[--parser_sqc_sp];
}




static int parser_hvar_stack_default[STACK_SIZE];
static int *parser_hvar_stack = parser_hvar_stack_default;
static int parser_hvar_sp = 0;
static int parser_hvar_limit = STACK_SIZE;

static void
parser_save_and_set_hvar (int value)
{
  if (parser_hvar_sp >= parser_hvar_limit)
    {
      int new_size = parser_hvar_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_hvar_stack, parser_hvar_limit);
      if (parser_hvar_stack != parser_hvar_stack_default)
	free (parser_hvar_stack);

      parser_hvar_stack = new_p;
      parser_hvar_limit *= 2;
    }

  parser_hvar_stack[parser_hvar_sp++] = parser_hostvar_check;
  parser_hostvar_check = value;
}

static void
parser_restore_hvar ()
{
  parser_hostvar_check = parser_hvar_stack[--parser_hvar_sp];
}




static int parser_oracle_stack_default[STACK_SIZE];
static int *parser_oracle_stack = parser_oracle_stack_default;
static int parser_oracle_sp = 0;
static int parser_oracle_limit = STACK_SIZE;

static void
parser_save_found_Oracle_outer ()
{
  if (parser_oracle_sp >= parser_oracle_limit)
    {
      int new_size = parser_oracle_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_oracle_stack, parser_oracle_limit);
      if (parser_oracle_stack != parser_oracle_stack_default)
	free (parser_oracle_stack);

      parser_oracle_stack = new_p;
      parser_oracle_limit *= 2;
    }

  parser_oracle_stack[parser_oracle_sp++] = parser_found_Oracle_outer;
}

static void
parser_restore_found_Oracle_outer ()
{
  parser_found_Oracle_outer = parser_oracle_stack[--parser_oracle_sp];
}



static PT_NODE *parser_alter_node_saved;

static void
parser_save_alter_node (PT_NODE * node)
{
  parser_alter_node_saved = node;
}


static PT_NODE *
parser_get_alter_node ()
{
  return parser_alter_node_saved;
}




static PT_NODE *parser_attr_def_one_saved;

static void
parser_save_attr_def_one (PT_NODE * node)
{
  parser_attr_def_one_saved = node;
}


static PT_NODE *
parser_get_attr_def_one ()
{
  return parser_attr_def_one_saved;
}




static PT_NODE *parser_orderby_node_stack_default[STACK_SIZE];
static PT_NODE **parser_orderby_node_stack =
  parser_orderby_node_stack_default;
static int parser_orderby_node_sp = 0;
static int parser_orderby_node_limit = STACK_SIZE;

static void
parser_push_orderby_node (PT_NODE * node)
{
  if (parser_orderby_node_sp >= parser_orderby_node_limit)
    {
      int new_size = parser_orderby_node_limit * 2 * sizeof(PT_NODE**);
      PT_NODE **new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_orderby_node_stack, parser_orderby_node_limit);
      if (parser_orderby_node_stack != parser_orderby_node_stack_default)
	free (parser_orderby_node_stack);

      parser_orderby_node_stack = new_p;
      parser_orderby_node_limit *= 2;
    }

  parser_orderby_node_stack[parser_orderby_node_sp++] = node;
}


static PT_NODE *
parser_top_orderby_node ()
{
  return parser_orderby_node_stack[parser_orderby_node_sp - 1];
}

static PT_NODE *
parser_pop_orderby_node ()
{
  return parser_orderby_node_stack[--parser_orderby_node_sp];
}




static PT_NODE *parser_select_node_stack_default[STACK_SIZE];
static PT_NODE **parser_select_node_stack = parser_select_node_stack_default;
static int parser_select_node_sp = 0;
static int parser_select_node_limit = STACK_SIZE;

static void
parser_push_select_stmt_node (PT_NODE * node)
{
  if (parser_select_node_sp >= parser_select_node_limit)
    {
      int new_size = parser_select_node_limit * 2 * sizeof(PT_NODE**);
      PT_NODE **new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_select_node_stack, parser_select_node_limit);
      if (parser_select_node_stack != parser_select_node_stack_default)
	free (parser_select_node_stack);

      parser_select_node_stack = new_p;
      parser_select_node_limit *= 2;
    }

  parser_select_node_stack[parser_select_node_sp++] = node;
}


static PT_NODE *
parser_top_select_stmt_node ()
{
  return parser_select_node_stack[parser_select_node_sp - 1];
}

static PT_NODE *
parser_pop_select_stmt_node ()
{
  return parser_select_node_stack[--parser_select_node_sp];
}





static PT_NODE *parser_hint_node_stack_default[STACK_SIZE];
static PT_NODE **parser_hint_node_stack = parser_hint_node_stack_default;
static int parser_hint_node_sp = 0;
static int parser_hint_node_limit = STACK_SIZE;

void
parser_push_hint_node (PT_NODE * node)
{
  if (parser_hint_node_sp >= parser_hint_node_limit)
    {
      int new_size = parser_hint_node_limit * 2 * sizeof(PT_NODE**);
      PT_NODE **new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_hint_node_stack, parser_hint_node_limit);
      if (parser_hint_node_stack != parser_hint_node_stack_default)
	free (parser_hint_node_stack);

      parser_hint_node_stack = new_p;
      parser_hint_node_limit *= 2;
    }

  parser_hint_node_stack[parser_hint_node_sp++] = node;
}


PT_NODE *
parser_top_hint_node ()
{
  return parser_hint_node_stack[parser_hint_node_sp - 1];
}

PT_NODE *
parser_pop_hint_node ()
{
  return parser_hint_node_stack[--parser_hint_node_sp];
}

static int parser_join_type_stack_default[STACK_SIZE];
static int *parser_join_type_stack = parser_join_type_stack_default;
static int parser_join_type_sp = 0;
static int parser_join_type_limit = STACK_SIZE;

static void
parser_push_join_type (int v)
{
  if (parser_join_type_sp >= parser_join_type_limit)
    {
      int new_size = parser_join_type_limit * 2 * sizeof(int);
      int *new_p = malloc (new_size);
      if (new_p == NULL)
	{
	  er_set (ER_ERROR_SEVERITY, ARG_FILE_LINE,
		  ER_OUT_OF_VIRTUAL_MEMORY, 1, new_size);
	  return;
	}

      memcpy (new_p, parser_join_type_stack, parser_join_type_limit);
      if (parser_join_type_stack != parser_join_type_stack_default)
	free (parser_join_type_stack);

      parser_join_type_stack = new_p;
      parser_join_type_limit *= 2;
    }

  parser_join_type_stack[parser_join_type_sp++] = v;
}


static int
parser_top_join_type ()
{
  return parser_join_type_stack[parser_join_type_sp - 1];
}

static int
parser_pop_join_type ()
{
  return parser_join_type_stack[--parser_join_type_sp];
}



static bool parser_is_reverse_saved;

static void
parser_save_is_reverse (bool v)
{
  parser_is_reverse_saved = v;
}


static bool
parser_get_is_reverse ()
{
  return parser_is_reverse_saved;
}


static int
parser_count_list (PT_NODE * list)
{
  int i = 0;
  PT_NODE *p = list;

  while (p)
    {
      p = p->next;
      i++;
    }

  return i;
}

static void
parser_stackpointer_init ()
{
  parser_select_node_sp = 0;
  parser_orderby_node_sp = 0;
  parser_oracle_sp = 0;
  parser_orderbynum_sp = 0;
  parser_groupbynum_sp = 0;
  parser_instnum_sp = 0;
  parser_wjc_sp = 0;
  parser_cannot_cache_sp = 0;
  parser_hint_node_sp = 0;
}


static void
parser_remove_dummy_select (PT_NODE ** ent_inout)
{
  PT_NODE *ent = *ent_inout;

  if (ent
      && ent->info.spec.derived_table_type == PT_IS_SUBQUERY
      && ent->info.spec.as_attr_list == NULL /* no attr_list */ )
    {

      PT_NODE *subq, *new_ent;

      /* remove dummy select from FROM clause
       *
       * for example:
       * case 1 (simple spec):
       *              FROM (SELECT * FROM x) AS s
       * -> FROM x AS s
       * case 2 (nested spec):
       *              FROM (SELECT * FROM (SELECT a, b FROM bas) y(p, q)) x
       * -> FROM (SELECT a, b FROM bas) x(p, q)
       */
      if ((subq = ent->info.spec.derived_table)
	  && subq->node_type == PT_SELECT
	  && PT_SELECT_INFO_IS_FLAGED (subq, PT_SELECT_INFO_DUMMY)
	  && subq->info.query.q.select.from)
	{
	  new_ent = subq->info.query.q.select.from;
	  subq->info.query.q.select.from = NULL;

	  /* free, reset new_spec's range_var, as_attr_list */
	  if (new_ent->info.spec.range_var)
	    {
	      parser_free_node (this_parser, new_ent->info.spec.range_var);
	      new_ent->info.spec.range_var = NULL;
	    }

	  new_ent->info.spec.range_var = ent->info.spec.range_var;
	  ent->info.spec.range_var = NULL;

	  /* free old ent, reset to new_ent */
	  parser_free_node (this_parser, ent);
	  *ent_inout = new_ent;
	}
    }
}


static PT_NODE *
parser_make_date_lang (int arg_cnt, PT_NODE * arg3)
{
  if (arg3 && arg_cnt == 3)
    {

      char *lang_str;
      PT_NODE *date_lang = parser_new_node (this_parser, PT_VALUE);

      if (date_lang)
	{
	  date_lang->type_enum = PT_TYPE_INTEGER;
	  if (arg3->type_enum != PT_TYPE_CHAR
	      && arg3->type_enum != PT_TYPE_NCHAR)
	    {
	      PT_ERROR (this_parser, arg3,
			"argument 3 must be character string");
	    }
	  else if (arg3->info.value.data_value.str != NULL)
	    {
	      lang_str = (char *) arg3->info.value.data_value.str->bytes;
	      if (strcasecmp (lang_str, LANG_NAME_KOREAN) == 0)
		{
		  date_lang->info.value.data_value.i = 4;
		}
	      else if (strcasecmp (lang_str, LANG_NAME_ENGLISH) == 0)
		{
		  date_lang->info.value.data_value.i = 2;
		}
	      else
		{		/* unknown */
		  PT_ERROR (this_parser, arg3, "check syntax at 'date_lang'");
		}
	    }
	}
      parser_free_node (this_parser, arg3);

      return date_lang;
    }
  else
    {
      PT_NODE *date_lang = parser_new_node (this_parser, PT_VALUE);
      if (date_lang)
	{
	  const char *lang_str;
	  date_lang->type_enum = PT_TYPE_INTEGER;
	  lang_str = envvar_get ("DATE_LANG");

	  if (lang_str && strcasecmp (lang_str, LANG_NAME_KOREAN) == 0)
	    date_lang->info.value.data_value.i = 4;
	  else
	    date_lang->info.value.data_value.i = 2;

	  if (arg_cnt == 1)
	    date_lang->info.value.data_value.i |= 1;
	}

      return date_lang;
    }
}



PT_NODE **
parser_main (PARSER_CONTEXT * parser)
{
  long desc_index = 0;
  long i, top;
  int rv;

  PARSER_CONTEXT *this_parser_saved;

  if (!parser)
    return 0;

  parser_output_host_index = parser_input_host_index = desc_index = 0;

  this_parser_saved = this_parser;

  this_parser = parser;

  dbcs_start_input ();

  yyline = 1;
  yycolumn = yycolumn_end = 1;

  rv = yyparse ();
  pt_cleanup_hint (parser, parser_hint_table);

  if (parser->error_msgs || parser->stack_top <= 0 || !parser->node_stack)
    {
      parser->statements = NULL;
    }
  else
    {
      /* create array of result statements */
      parser->statements = (PT_NODE **) parser_alloc (parser,
						      (1 +
						       parser->stack_top) *
						      sizeof (PT_NODE *));
      if (parser->statements)
	{
	  for (i = 0, top = parser->stack_top; i < top; i++)
	    {
	      parser->statements[i] = parser->node_stack[i];
	    }
	  parser->statements[top] = NULL;
	}
      /* record parser_input_host_index into parser->host_var_count for later use;
        e.g. parser_set_host_variables(), auto-parameterized query */
      parser->host_var_count = parser_input_host_index;
      if (parser->host_var_count > 0)
	{
	  /* allocate place holder for host variables */
	  parser->host_variables = (DB_VALUE *)
	    malloc (parser->host_var_count * sizeof (DB_VALUE));
	  if (!parser->host_variables)
	    {
	      parser->statements = NULL;
	    }
	  else
	    {
	      (void) memset (parser->host_variables, 0,
			     parser->host_var_count * sizeof (DB_VALUE));
	    }
	}
    }

  this_parser = this_parser_saved;
  return parser->statements;
}





extern int parser_yyinput_single_mode;
int
parse_one_statement (int state)
{
  int rv;

  if (state == 0)
    {
      return 0;
    }

  this_parser->statement_number = 0;

  parser_yyinput_single_mode = 1;

  rv = yyparse ();
  pt_cleanup_hint (this_parser, parser_hint_table);

  if (parser_statement_OK)
    this_parser->statement_number = 1;
  else
    parser_statement_OK = 1;

  if (!parser_yyinput_single_mode)	/* eof */
    return 1;

  return 0;
}


PT_HINT parser_hint_table[] = {
  {"ORDERED", NULL, PT_HINT_ORDERED}
  ,
  {"USE_NL", NULL, PT_HINT_USE_NL}
  ,
  {"USE_IDX", NULL, PT_HINT_USE_IDX}
  ,
  {"USE_MERGE", NULL, PT_HINT_USE_MERGE}
  ,
  {"RECOMPILE", NULL, PT_HINT_RECOMPILE}
  ,
  {"LOCK_TIMEOUT", NULL, PT_HINT_LK_TIMEOUT}
  ,
  {"NO_LOGGING", NULL, PT_HINT_NO_LOGGING}
  ,
  {"RELEASE_LOCK", NULL, PT_HINT_REL_LOCK}
  ,
  {"QUERY_CACHE", NULL, PT_HINT_QUERY_CACHE}
  ,
  {"REEXECUTE", NULL, PT_HINT_REEXECUTE}
  ,
  {"JDBC_CACHE", NULL, PT_HINT_JDBC_CACHE}
  ,
  {"NO_STATS", NULL, PT_HINT_NO_STATS}
  ,
  {NULL, NULL, -1}		/* mark as end */
};



static int
function_keyword_cmp (const void *f1, const void *f2)
{
  return strcasecmp (((FUNCTION_MAP *) f1)->keyword,
                 ((FUNCTION_MAP *) f2)->keyword);
}



FUNCTION_MAP*
keyword_offset (const char *text)
{
  static bool function_keyword_sorted = false;
  FUNCTION_MAP dummy;
  FUNCTION_MAP *result_key;

  if (function_keyword_sorted == false)
    {
      qsort (functions,
	     (sizeof (functions) / sizeof (functions[0])),
	     sizeof (functions[0]), function_keyword_cmp);

      function_keyword_sorted = true;
    }

  if (!text)
    {
      return NULL;
    }

  if (strlen (text) >= MAX_KEYWORD_SIZE)
    {
      return NULL;
    }

  dummy.keyword = text;

  result_key =
      (FUNCTION_MAP *) bsearch (&dummy, functions,
				(sizeof (functions) / sizeof (functions[0])),
				sizeof (FUNCTION_MAP), function_keyword_cmp);

  return result_key;
}


PT_NODE *
keyword_func (const char *name, PT_NODE * args)
{
  PT_NODE *node;
  PT_NODE *a1, *a2, *a3;
  FUNCTION_MAP* key;
  int c;

  parser_function_code = PT_EMPTY;
  c = parser_count_list (args);
  key = keyword_offset (name);
  if (key == NULL)
    return NULL;

  parser_function_code = key->op;

  a1 = a2 = a3 = NULL;
  switch (key->op)
    {
      /* arg 0 */
    case PT_PI:
    case PT_SYS_TIME:
    case PT_SYS_DATE:
    case PT_SYS_DATETIME:
    case PT_SYS_TIMESTAMP:
      if (c != 0)
	{
	  return NULL;
	}
      return parser_make_expression (key->op, NULL, NULL, NULL);
      break;

    case PT_ROW_COUNT:
      if (c != 0)
        {
	  return NULL;
	}
      parser_cannot_cache = true;
      parser_cannot_prepare = true;
      return parser_make_expression (key->op, NULL, NULL, NULL);
      break;

      /* arg 0 or 1 */
    case PT_RAND:
    case PT_RANDOM:
    case PT_DRAND:
    case PT_DRANDOM:
      {
	PT_NODE *expr;
        parser_cannot_cache = true;

	if (c < 0 || c > 1)
	  {
	    return NULL;
	  }

	if (c == 1)
	  {
	    a1 = args;
	  }
	expr = parser_make_expression (key->op, a1, NULL, NULL);
	expr->do_not_fold = 1;
	return expr;
      }

      /* arg 1 */
    case PT_ABS:
    case PT_CEIL:
    case PT_CHAR_LENGTH:	/* char_length, length, lengthb */
    case PT_CHR:
    case PT_EXP:
    case PT_FLOOR:
    case PT_LAST_DAY:
    case PT_SIGN:
    case PT_SQRT:
    case PT_ACOS:
    case PT_ASIN:
    case PT_COS:
    case PT_SIN:
    case PT_TAN:
    case PT_COT:
    case PT_DEGREES:
    case PT_RADIANS:
    case PT_LN:
    case PT_LOG2:
    case PT_LOG10:
      if (c != 1)
		return NULL;
      a1 = args;
      return parser_make_expression (key->op, a1, NULL, NULL);
      break;
    case PT_UNIX_TIMESTAMP:
      if (c > 1)
		return NULL;
      if (c == 1)
		{
		  a1 = args;
		  return parser_make_expression (key->op, a1, NULL, NULL);
		}
	  else /* no arguments */
		{
		  return parser_make_expression (key->op, NULL, NULL, NULL);
		}
      break;

      /* arg 2 */
    case PT_LOG:
    case PT_MONTHS_BETWEEN:
    case PT_NVL:
    case PT_POWER:
    case PT_TIME_FORMAT:
    case PT_FORMAT:
    case PT_DATE_FORMAT:
    case PT_ATAN2:
    case PT_DATEDIFF:
      if (c != 2)
	return NULL;
      a1 = args;
      a2 = a1->next;
      a1->next = NULL;
      return parser_make_expression (key->op, a1, a2, NULL);
      break;

    case PT_ATAN:
      if (c == 1)
	{
	  a1 = args;
	  return parser_make_expression (key->op, a1, NULL, NULL);
	}
      else
      if (c == 2)
	{
	  a1 = args;
	  a2 = a1->next;
	  a1->next = NULL;
	  return parser_make_expression (PT_ATAN2, a1, a2, NULL);
	}
      else
	return NULL;
      break;

    /* arg 3 */
    case PT_NVL2:
      if (c != 3)
	return NULL;
      a1 = args;
      a2 = a1->next;
      a3 = a2->next;
      a1->next = a2->next = NULL;
      return parser_make_expression (key->op, a1, a2, a3);
      break;

      /* arg 1 + default */
    case PT_ROUND:
    case PT_TRUNC:
      if (c == 1)
	{
	  a1 = args;
	  a2 = parser_new_node (this_parser, PT_VALUE);
	  if (a2)
	    {
	      a2->type_enum = PT_TYPE_INTEGER;
	      a2->info.value.data_value.i = 0;
	    }

	  return parser_make_expression (key->op, a1, a2, NULL);
	}

      if (c != 2)
	return NULL;
      a1 = args;
      a2 = a1->next;
      a1->next = NULL;
      return parser_make_expression (key->op, a1, a2, NULL);
      break;

      /* arg 2 + default */
    case PT_INSTR:		/* instr, instrb */
      if (c == 2)
	{
	  a3 = parser_new_node (this_parser, PT_VALUE);
	  if (a3)
	    {
	      a3->type_enum = PT_TYPE_INTEGER;
	      a3->info.value.data_value.i = 1;
	    }

	  a1 = args;
	  a2 = a1->next;
	  a1->next = NULL;

	  return parser_make_expression (key->op, a1, a2, a3);
	}

      if (c != 3)
	return NULL;
      a1 = args;
      a2 = a1->next;
      a3 = a2->next;
      a1->next = a2->next = NULL;
      return parser_make_expression (key->op, a1, a2, a3);
      break;

      /* arg 1 or 2 */
    case PT_LTRIM:
    case PT_RTRIM:
      if (c < 1 || c > 2)
	return NULL;
      a1 = args;
      if (a1)
	a2 = a1->next;
      a1->next = NULL;
      return parser_make_expression (key->op, a1, a2, a3);
      break;

      /* arg 1 or 2 */
    case PT_TO_NUMBER:
      if (c < 1 || c > 2)
	{
	  push_msg (MSGCAT_SYNTAX_INVALID_TO_NUMBER);
	  csql_yyerror_explicit(10, 10);
	  return NULL;
	}

      if (c == 2)
	{
	  PT_NODE* node = args->next;
	  if (  node->node_type != PT_VALUE ||
	      ( node->type_enum != PT_TYPE_CHAR &&
	        node->type_enum != PT_TYPE_NCHAR) )
	    {
	      push_msg (MSGCAT_SYNTAX_INVALID_TO_NUMBER);
	      csql_yyerror_explicit(10, 10);
	      return NULL;
	    }
	}

      a1 = args;
      if (a1)
	a2 = a1->next;
      a1->next = NULL;
      return parser_make_expression (key->op, a1, a2, a3);
      break;

      /* arg 2 or 3 */
    case PT_LPAD:
    case PT_RPAD:
    case PT_SUBSTRING:		/* substr, substrb */

      if (c < 2 || c > 3)
	return NULL;

      a1 = args;
      a2 = a1->next;
      if (a2)
	{
	  a3 = a2->next;
	  a2->next = NULL;
	}

      a1->next = NULL;

      node = parser_make_expression (key->op, a1, a2, a3);
      if (key->op == PT_SUBSTRING)
	{
	  node->info.expr.qualifier = PT_SUBSTR;
	  PICE (node);
	}

      return node;
      break;

    case PT_ORDERBY_NUM:
      if (c != 0)
	return NULL;

      node = parser_new_node (this_parser, PT_EXPR);
      if (node)
	{
	  node->info.expr.op = PT_ORDERBY_NUM;
	  PT_EXPR_INFO_SET_FLAG (node, PT_EXPR_INFO_ORDERBYNUM_C);
	}

      if (parser_orderbynum_check == 0)
	PT_ERRORmf2 (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
		     MSGCAT_SEMANTIC_INSTNUM_COMPATIBILITY_ERR,
		     "ORDERBY_NUM()", "ORDERBY_NUM()");

      parser_groupby_exception = PT_ORDERBY_NUM;
      return node;
      break;

    case PT_INST_NUM:
      if (c != 0)
	return NULL;

      node = parser_new_node (this_parser, PT_EXPR);

      if (node)
	{
	  node->info.expr.op = PT_INST_NUM;
	  PT_EXPR_INFO_SET_FLAG (node, PT_EXPR_INFO_INSTNUM_C);
	}

      if (parser_instnum_check == 0)
	PT_ERRORmf2 (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
		     MSGCAT_SEMANTIC_INSTNUM_COMPATIBILITY_ERR,
		     "INST_NUM() or ROWNUM", "INST_NUM() or ROWNUM");

      parser_groupby_exception = PT_INST_NUM;
      return node;
      break;

    case PT_INCR:
    case PT_DECR:
      if (c != 1)
	return NULL;
      node = parser_make_expression (key->op, args, NULL, NULL);

      if ((args->node_type != PT_NAME && args->node_type != PT_DOT_) ||
	  (args->node_type == PT_NAME && args->info.name.tag_click_counter) ||
	  (args->node_type == PT_DOT_ && args->info.dot.tag_click_counter))
	{
	  PT_ERRORf (this_parser, node,
		     "%s argument must be identifier or dotted identifier(path expression)",
		     pt_short_print (this_parser, node));
	}

      if (parser_select_level != 1)
	{
	  PT_ERRORf (this_parser, node,
		     "%s can be used at top select statement only.",
		     pt_short_print (this_parser, node));
	}
      node->is_hidden_column = 1;
      parser_hidden_incr_list =
	parser_append_node (node, parser_hidden_incr_list);
      if ((a1 = parser_copy_tree (this_parser, node->info.expr.arg1)) == NULL)
	{
	  return NULL;
	}

      parser_cannot_cache = true;

      if (a1->node_type == PT_NAME)
	a1->info.name.tag_click_counter = 1;
      else if (a1->node_type == PT_DOT_)
	a1->info.dot.tag_click_counter = 1;
      return a1;
      break;

    case PT_TO_CHAR:
    case PT_TO_DATE:
    case PT_TO_TIME:
    case PT_TO_TIMESTAMP:
    case PT_TO_DATETIME:
      if (c < 1 || c > 3)
	return NULL;
      a1 = args;
      a2 = a1->next;
      a1->next = NULL;

      if (a2)
	{
	  a3 = a2->next;
	}

      if (a2)
	{
	  a2->next = NULL;
	}

      if (c == 1)
	{
	  a2 = parser_new_node (this_parser, PT_VALUE);

	  if (a2)
	    {
	      a2->type_enum = PT_TYPE_NULL;
	    }
	}

      return parser_make_expression (key->op, a1, a2,
				     parser_make_date_lang (c, a3));
      break;

    case PT_DECODE:
      {
	int i;
	PT_NODE *case_oper, *ppp, *qqq, *rrr, *nodep, *node, *curr, *prev;
	int count;

	if (c < 3)
	  return NULL;

	case_oper = args;
	ppp = args->next;
	args->next = NULL;
	curr = ppp->next;
	ppp->next = NULL;

	node = parser_new_node (this_parser, PT_EXPR);
	if (node)
	  {
	    node->info.expr.op = PT_DECODE;
	    qqq = parser_new_node (this_parser, PT_EXPR);
	    if (qqq)
	      {
		qqq->info.expr.op = PT_EQ;
		qqq->info.expr.qualifier = PT_EQ_TORDER;
		qqq->info.expr.arg1 =
		  parser_copy_tree_list (this_parser, case_oper);
		qqq->info.expr.arg2 = ppp;
		node->info.expr.arg3 = qqq;
		PICE (qqq);
	      }

	    ppp = curr->next;
	    curr->next = NULL;
	    node->info.expr.arg1 = curr;
	    PICE (node);
	  }

	prev = node;
	count = parser_count_list (ppp);
	for (i = 1; i <= count; i++)
	  {
	    if (i % 2 == 0)
	      {
		rrr = ppp->next;
		ppp->next = NULL;
		nodep = parser_new_node (this_parser, PT_EXPR);
		if (nodep)
		  {
		    nodep->info.expr.op = PT_DECODE;
		    qqq = parser_new_node (this_parser, PT_EXPR);
		    if (qqq)
		      {
			qqq->info.expr.op = PT_EQ;
			qqq->info.expr.qualifier = PT_EQ_TORDER;
			qqq->info.expr.arg1 =
			  parser_copy_tree_list (this_parser, case_oper);
			qqq->info.expr.arg2 = ppp;
			nodep->info.expr.arg3 = qqq;
			PICE (nodep);
		      }
		    nodep->info.expr.arg1 = rrr;
		    nodep->info.expr.continued_case = 1;
		  }
		PICE (nodep);

		if (prev)
		  prev->info.expr.arg2 = nodep;
		PICE (prev);
		prev = nodep;

		ppp = rrr->next;
		rrr->next = NULL;
	      }
	  }

	/* default value */
	if (i % 2 == 0)
	  {
	    if (prev)
	      prev->info.expr.arg2 = ppp;
	    PICE (prev);
	  }
	else if (prev && prev->info.expr.arg2 == NULL)
	  {
	    ppp = parser_new_node (this_parser, PT_VALUE);
	    if (ppp)
	      ppp->type_enum = PT_TYPE_NULL;
	    prev->info.expr.arg2 = ppp;
	    PICE (prev);
	  }

	if (case_oper)
	  parser_free_node (this_parser, case_oper);

	return node;
      }
      break;

    case PT_LEAST:
    case PT_GREATEST:
      {
	PT_NODE *prev, *expr, *arg, *tmp;
	int i;
	arg = args;

	if (c < 1)
	  return NULL;

	expr = parser_new_node (this_parser, PT_EXPR);
	if (expr)
	  {
	    expr->info.expr.op = key->op;
	    expr->info.expr.arg1 = arg;
	    expr->info.expr.arg2 = NULL;
	    expr->info.expr.arg3 = NULL;
	    expr->info.expr.continued_case = 1;
	  }

	PICE (expr);
	prev = expr;

	if (c > 1)
	  {
	    tmp = arg;
	    arg = arg->next;
	    tmp->next = NULL;

	    if (prev)
	      prev->info.expr.arg2 = arg;
	    PICE (prev);
	  }
	for (i = 3; i <= c; i++)
	  {
	    tmp = arg;
	    arg = arg->next;
	    tmp->next = NULL;

	    expr = parser_new_node (this_parser, PT_EXPR);
	    if (expr)
	      {
		expr->info.expr.op = key->op;
		expr->info.expr.arg1 = prev;
		expr->info.expr.arg2 = arg;
		expr->info.expr.arg3 = NULL;
		expr->info.expr.continued_case = 1;
	      }

	    if (prev && prev->info.expr.continued_case >= 1)
	      prev->info.expr.continued_case++;
	    PICE (expr);
	    prev = expr;
	  }

	if (expr && expr->info.expr.arg2 == NULL)
	  {
	    expr->info.expr.arg2 =
	      parser_copy_tree_list (this_parser, expr->info.expr.arg1);
            expr->info.expr.arg2->is_hidden_column = 1;
	  }

	return expr;
      }
      break;

    case PT_CONCAT:
    case PT_CONCAT_WS:
    case PT_FIELD:
      {
	PT_NODE *prev, *expr, *arg, *tmp, *sep, *val;
	int i, ws;
	arg = args;

	ws = (key->op != PT_CONCAT) ? 1 : 0;
	if (c < 1 + ws)
	  return NULL;

	if (key->op != PT_CONCAT)
	  {
	    sep = arg;
	    arg = arg->next;
	  }
	else
	  {
	    sep = NULL;
	  }

	expr = parser_new_node (this_parser, PT_EXPR);
	if (expr)
	  {
	    expr->info.expr.op = key->op;
	    expr->info.expr.arg1 = arg;
	    expr->info.expr.arg2 = NULL;
	    if (key->op == PT_FIELD && sep)
	      {
		val = parser_new_node (this_parser, PT_VALUE);
		if (val)
		  {
		    val->type_enum = PT_TYPE_INTEGER;
		    val->info.value.data_value.i = 1;
		    val->is_hidden_column = 1;
		  }
		expr->info.expr.arg3 = parser_copy_tree (this_parser, sep);
		expr->info.expr.arg3->next = val;
	      }
	    else
	      {
		expr->info.expr.arg3 = sep;
	      }
	    expr->info.expr.continued_case = 1;
	  }

	PICE (expr);
	prev = expr;

	if (c > 1 + ws)
	  {
	    tmp = arg;
	    arg = arg->next;
	    tmp->next = NULL;

	    if (prev)
	      prev->info.expr.arg2 = arg;
	    PICE (prev);
	  }
	for (i = 3 + ws; i <= c; i ++)
	  {
	    tmp = arg;
	    arg = arg->next;
	    tmp->next = NULL;

	    expr = parser_new_node (this_parser, PT_EXPR);
	    if (expr)
	      {
		expr->info.expr.op = key->op;
		expr->info.expr.arg1 = prev;
		expr->info.expr.arg2 = arg;
		if (sep)
		  {
		    expr->info.expr.arg3 = parser_copy_tree (this_parser, sep);
		    if (key->op == PT_FIELD)
		      {
			val = parser_new_node (this_parser, PT_VALUE);
			if (val)
			  {
			    val->type_enum = PT_TYPE_INTEGER;
			    val->info.value.data_value.i = i-ws;
			    val->is_hidden_column = 1;
			  }
			expr->info.expr.arg3->next = val;
		      }
		  }
		else
		  {
		    expr->info.expr.arg3 = NULL;
		  }
		expr->info.expr.continued_case = 1;
	      }

	    if (prev && prev->info.expr.continued_case >= 1)
	      prev->info.expr.continued_case++;
	    PICE (expr);
	    prev = expr;
	  }

	if (key->op == PT_FIELD && expr && expr->info.expr.arg2 == NULL)
	  {
	    val = parser_new_node (this_parser, PT_VALUE);
	    if (val)
	      {
		val->type_enum = PT_TYPE_NULL;
		val->is_hidden_column = 1;
	      }
	    expr->info.expr.arg2 = val;
	  }

	return expr;
      }
      break;

    case PT_LOCATE:
      if (c < 2 || c > 3)
	return NULL;

      a1 = args;
      a2 = a1->next;
      if (a2)
	{
	  a3 = a2->next;
	  a2->next = NULL;
	}
      a1->next = NULL;

      node = parser_make_expression (key->op, a1, a2, a3);
      return node;

    case PT_MID:
      if (c != 3)
	return NULL;

      a1 = args;
      a2 = a1->next;
      a3 = a2->next;
      a1->next = NULL;
      a2->next = NULL;
      a3->next = NULL;

      node = parser_make_expression (key->op, a1, a2, a3);
      return node;

    case PT_STRCMP:
      if (c != 2)
	return NULL;

      a1 = args;
      a2 = a1->next;
      a1->next = NULL;

      node = parser_make_expression (key->op, a1, a2, a3);
      return node;

    case PT_REVERSE:
      if (c != 1)
	return NULL;

      a1 = args;
      node = parser_make_expression (key->op, a1, NULL, NULL);
      return node;

    case PT_BIT_COUNT:
      if (c != 1)
	return NULL;

      a1 = args;
      node = parser_make_expression (key->op, a1, NULL, NULL);
      return node;

    case PT_GROUPBY_NUM:
      if (c != 0)
	return NULL;

      node = parser_new_node (this_parser, PT_FUNCTION);

      if (node)
	{
	  node->info.function.function_type = PT_GROUPBY_NUM;
	  node->info.function.arg_list = NULL;
	  node->info.function.all_or_distinct = PT_ALL;
	}

      if (parser_groupbynum_check == 0)
	PT_ERRORmf2 (this_parser, node, MSGCAT_SET_PARSER_SEMANTIC,
		     MSGCAT_SEMANTIC_INSTNUM_COMPATIBILITY_ERR,
		     "GROUPBY_NUM()", "GROUPBY_NUM()");

      return node;

      break;

    case PT_LIST_DBS:
      if (c != 0)
	return NULL;
      node = parser_make_expression (key->op, NULL, NULL, NULL);
      return node;

    default:
      return NULL;
    }

  return NULL;
}


static void
resolve_alias_in_expr_node (PT_NODE * node, PT_NODE * list)
{
  if (!node)
    {
      return;
    }

  switch (node->node_type)
    {
    case PT_SORT_SPEC:
      if (node->info.sort_spec.expr
	  && node->info.sort_spec.expr->node_type == PT_NAME)
	{
	  resolve_alias_in_name_node (&node->info.sort_spec.expr, list);
	}
      else
	{
	  resolve_alias_in_expr_node (node->info.sort_spec.expr, list);
	}
      break;

    case PT_EXPR:
      if (node->info.expr.arg1
	  && node->info.expr.arg1->node_type == PT_NAME)
	{
	  resolve_alias_in_name_node (&node->info.expr.arg1, list);
	}
      else
	{
	  resolve_alias_in_expr_node (node->info.expr.arg1, list);
	}
      if (node->info.expr.arg2
	  && node->info.expr.arg2->node_type == PT_NAME)
	{
	  resolve_alias_in_name_node (&node->info.expr.arg2, list);
	}
      else
	{
	  resolve_alias_in_expr_node (node->info.expr.arg2, list);
	}
      if (node->info.expr.arg3
	  && node->info.expr.arg3->node_type == PT_NAME)
	{
	  resolve_alias_in_name_node (&node->info.expr.arg3, list);
	}
      else
	{
	  resolve_alias_in_expr_node (node->info.expr.arg3, list);
	}
      break;

    default:;
    }
}


static void
resolve_alias_in_name_node (PT_NODE ** node, PT_NODE * list)
{
  PT_NODE *col;
  char *n_str, *c_str;
  bool resolved = false;

  n_str = parser_print_tree (this_parser, *node);

  for (col = list; col; col = col->next)
    {
      if (col->node_type == PT_NAME)
	{
	  c_str = parser_print_tree (this_parser, col);
	  if (c_str == NULL)
	    {
	      continue;
	    }

	  if (intl_mbs_casecmp (n_str, c_str) == 0)
	    {
	      resolved = true;
	      break;
	    }
	}
    }

  if (resolved != true)
    {
      for (col = list; col; col = col->next)
	{
	  if (col->alias_print
	      && intl_mbs_casecmp (n_str, col->alias_print) == 0)
	    {
	      parser_free_node (this_parser, *node);
	      *node = parser_copy_tree (this_parser, col);
	      (*node)->next = NULL;
	      break;
	    }
	}
    }
}