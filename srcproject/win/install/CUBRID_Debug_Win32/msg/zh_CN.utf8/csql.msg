
$
$ Copyright (C) 2008 Search Solution Corporation. All rights reserved by Search Solution. 
$
$   This program is free software; you can redistribute it and/or modify 
$   it under the terms of the GNU General Public License as published by 
$   the Free Software Foundation; either version 2 of the License, or
$   (at your option) any later version. 
$
$  This program is distributed in the hope that it will be useful, 
$  but WITHOUT ANY WARRANTY; without even the implied warranty of 
$  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
$  GNU General Public License for more details. 
$
$  You should have received a copy of the GNU General Public License 
$  along with this program; if not, write to the Free Software 
$  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
$

$
$ $Id$
$
$ csql.msg
$

$set 1 MSGCAT_CSQL_SET_CSQL
40 \
交互型SQL工具, 版本 %s\n\
用法 %s [选项] 数据库名\n\
\n\
可用选项:\n\
  -S, --SA-mode                单机模式执行\n\
  -C, --CS-mode                客户端服务器模式执行\n\
  -u, --user=ARG               用户名\n\
  -p, --pasword=ARG            密码字符串，用""表示密码为空\n\
  -e, --error-continue         在语句错误时不退出\n\
  -i, --input-file=ARG         输入文件名\n\
  -o, --output-file=ARG        输出文件名\n\
  -s, --single-line            面向单行的执行\n\
  -c, --command=ARG            CSQL命令\n\
  -l, --line-output            每个值都用单独的行表示\n\
  -r, --read-only              只读模式\n\
      --no-auto-commit         禁用自动提交执行模式\n\
      --no-pager               不要将查询结果分页\n\
\n\
额外的信息, 请浏览 http://www.cubrid.com\n
41 %s: 环境变量 %s_MODE 的值是不正确的. \n它应该是 %s 或 %s.\n
42 %s: 太多的参数被给定. 最大参数个数是 %d.\n
43 %s: 根目录环境变量($CUBRID) 应当被设置.\n
44 %s: 尝试执行 "%s" 失败.\n
45 %s: 无法同时使用 -sa 和 -cs 选项.\n
46 %d 条指令被成功处理.
47 在行 %d 中的命令,
48 在行 %d, 列 %d,
49 输入 `;help' 来显示帮助消息.
50 错误: 
51 CUBRID SQL 解释器
52 存在更新. 你想提交吗 ? (`Y' 或 `N') 
53 输入 `Y' 来提交, `N' 来取消. 
54 当前事务已提交.
55 当前事务已回滚.
56 命令缓冲区已经保存.
57 文件已被读取到命令缓冲区.
58 命令缓冲区的内容已被发送到打印机.
59 当前目录被改变到: 
61 输入密码: 
62 <命令 %s 在行 %d 的结果>
63 没有结果.
64 检测点被应用.
65 数据库已被重启.
66 事务索引        用户名         主机名         进程标识符      程序名\n
67 %7d(%1c) %14s %14s %15d %17s\n
68 指定的事务已被结束.
69 结束指定的事务失败.
70 %d 行 %s.
71 %d 行 %s.
$ These 3 should be blank
75 自动化API测试器
76 无效的自动化API测试器
79 csql>
80 csql
81 sysadm>

145 <帮助: 类的结构>
146 无
147 <帮助: 所有的触发器>
148 <帮助: 没有已定义的触发器>
150 <帮助: 触发器定义>
151 <帮助: 命令语法>
152 <帮助: 会话命令总结>
178 需要一个文件名.
179 无法执行页面调度程序.
180 没有申请到足够的内存.
184 输入的行太长.
185 输入了太多的行.
188 输入了太多的文件名.
190 没有这个会话命令. 输入`;help' 来显示帮助信息.
191 一个以上的会话命令被匹配. 请更详细的指明.
192 没有这个命令. 输入 `;syntax general' 来查看可用的命令.
193 一个以上的命令被匹配. 请更详细的指明.
194 无效的命令选项组合.
196 发生了一个未定义的错误.
197 当输出被重定向 ';edit' 是不被允许的.

203 <%s> 
204 <父类> 
205 <子类> 
206 <属性> 
207 <类属性> 
208 <方法> 
209 <类方法> 
210 <解决方案> 
211 <方法文件> 
212 <查询详述> 
213 <触发器> 
214 <名字> 
215 <事件> 
216 <条件时间> 
217 <条件> 
218 <动作时间> 
219 <动作> 
220 <状态> 
221 <优先级> 
222 <名字> 
223 <描述> 
224 <语法> 
225 <例子> 

$ csql help messages
231 \
\n\
   所有的会话命令应当以`;' 作为前缀并且只有空格/制表符\n\
   可以在前缀之前. 大写的字母代表为了执行一条特定的命令,\n\
   所需的最少的缩写.\n\
\n\
   ;REAd   [<file-name>]       - 将一个文件读取到命令缓冲区.\n\
   ;Write  [<file-name>]       - 用命令缓冲区的内容重写一个文件.\n\
   ;APpend [<file-name>]       - 将命令缓冲区的内容追加到一个文件.\n\
   ;PRINT                      - 打印命令缓冲区.\n\
   ;SHELL                      - 调用shell.\n\
   ;CD                         - 改变当前工作目录.\n\
   ;EXit                       - 退出程序.\n\
\n\
   ;CLear                      - 清理命令缓冲区.\n\
   ;EDIT                       - 对命令缓冲区调用系统编辑器.\n\
   ;List                       - 显示当前命令缓冲区的内容.\n\
\n\
   ;RUn                        - 执行命令缓冲区的sql.\n\
   ;Xrun                       - 执行命令缓冲区的sql,\n\
                                 并清理命令缓冲区.\n\
   ;COmmit                     - 提交当前事务.\n\
   ;ROllback                   - 回滚当前事务.\n\
   ;AUtocommit [ON|OFF]        - 启用/停用自动提交模式.\n\
   ;REStart                    - 重新启动数据库.\n\
\n\
   ;SHELL_Cmd  [shell-cmd]     - 设置默认的shell或显示当前设置.\n\
   ;EDITOR_Cmd [editor-cmd]    - 设置默认编辑器或显示当前设置.\n\
   ;PRINT_Cmd  [print-cmd]     - 设置默认print或显示当前设置.\n\
   ;PAger_cmd  [pager-cmd]     - 设置默认页面调度器或显示当前设置\n\
\n\
   ;DATE                       - 显示本地时间,日期.\n\
   ;DATAbase                   - 显示正被访问的数据库名.\n\
   ;SChema class-name          - 显示类的结构信息.\n\
   ;SYntax [sql-cmd-name]      - 显示命令的语法.\n\
   ;TRigger [`*'|trigger-name] - 显示触发器的定义.\n\
   ;Get system_parameter       - 获取一个系统参数的值.\n\
   ;SEt system_parameter=value - 设置一个系统参数的值.\n\
   ;PLan [simple/detail/off]   - 显示查询执行计划.\n\
   ;Info <command>             - 显示内部信息.\n\
   ;TIme [ON/OFF]              - 启用/停用 显示查询\n\
                                 执行时间.\n\
   ;HISTORYList                - 显示已经执行的查询列表.\n\
   ;HISTORYRead <history_num>  - 将histroy_num所对应的内容读取到命令缓冲区.\n\
   ;HElp                       - 显示帮助信息.\n\n

232 <系统规定参数> 
233 Info {schema|trigger|deferred|workspace|lock|stats}\n\
\tschema [class-name]    - 结构信息\n\
\ttrigger [trigger-name] - 触发器信息\n\
\tdeferred               - 延迟触发信息\n\
\tworkspace              - 工作空间信息\n\
\tlock                   - 锁信息(客户端-服务端模式)\n\
\tstats class-name       - 类统计信息\n\
\ttrantable              - 事务信息\n\
\tlogstat                - 日志信息\n\
\tcsstat                 - 临界区信息\n\
\tplan                   - 计划缓存信息\n\
\tqcache                 - 查询缓存信息\n
235 <分区>
236 需要一个类名.
