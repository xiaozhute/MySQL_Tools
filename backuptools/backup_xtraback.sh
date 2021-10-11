#!/bin/bash

# 加载配置文件信息
while read line;do
    eval "$line"
done < backup_config.txt

# 钉钉信息发送
dingding_note(){
  if [[ $2 == "通知" ]]; then
    local color="#006600"
  else
    local color="#FF0033"
  fi
  local msg="## **$1[<font color=${color}>$2</font>]**\n&nbsp;  \n---\n#### **$2内容**:$3\n\n&nbsp;  \n\n---\n#### **$2时间:**\n* `date "+%Y-%m-%d %H:%M:%S"`"
  local INFO="curl -H \"Content-Type: application/json\"  -X POST -d '{\"msgtype\": \"markdown\",\"markdown\": {\"title\": \"${msg_title}$2\",\"text\": \"${msg}\"},\"at\":{\"atMobiles\": \"[+86-13382223538]\",\"isAtAll\": false}}' "${dingding_url}""
  eval ${INFO}
  if [[ $2 == "异常" ]]; then
    exit 1
  fi
}

# 邮件消息推送
mail_note()
{
    local mail_msg="<h2>$1[$2]<h3>通知内容：</h3>$3<h3>通知时间：</h3><p>`date "+%Y-%m-%d %H:%M:%S"`</p></h2>"
    sendemail -f $email_sender -t "$email_reciver" -s $email_smtphost -u "$email_title" -o message-content-type=html -o message-charset=utf8 -xu $email_username -xp $email_password -m "$mail_msg"
    if [[ $2 == "异常" ]]; then
      exit 1
    fi
}

# 初始化环境检测
# 本地备份路径和日志路径不存在则会创建，
backup_environment_check()
{
    if [ ! -d ${backup_dir} ] || [ ! -d ${backup_log_dir} ];then
        mkdir -p ${backup_dir} ${backup_log_dir}
    fi
    if [ ! -x ${xtrabackup_path} ];then
      if [[ $is_mail_warning -eq 1 ]]; then
        mail_note $email_title "异常" "<p>服务器IP：${host_ip}<br></p><h2>${xtrabackup_path}命令不存在，请检查!</h2>"
      fi
      if [[ $is_dingding_warning -eq 1 ]]; then
        dingding_note $msg_title "异常" "\n* 服务器IP：${host_ip}\n* ${xtrabackup_path}命令不存在，请检查!"
      fi
    fi
}

# 执行备份
do_backup()
{
    back_begin_time=`date "+%Y-%m-%d %H:%M:%S"`
    # 备份语句
    ${xtrabackup_path} --defaults-file=${mysql_cnf} --socket=${mysql_sock} --backup --user=${user} --password=${pwd} --target-dir=${target_dir_full}_${back_day} --parallel=4 > ${log_dir_full}.${back_day} 2>&1
    if [[ $? -ne 0 ]]; then
      if [[ $is_mail_warning -eq 1 ]]; then
        mail_note $email_title "异常" "<p>服务器IP：${host_ip}<br></p><h2>Mysql备份异常，请检查!</h2>"
      fi
      if [[ $is_dingding_warning -eq 1 ]]; then
        dingding_note $msg_title "异常" "\n* 服务器IP：${host_ip}\n* Mysql备份异常，请检查!"
      fi
    else
      back_end_time=`date "+%Y-%m-%d %H:%M:%S"`
      backup_filename=`ls ${backup_dir} | grep ${back_day}`
      backup_filesize=`du -sh ${backup_dir}/${backup_filename}|awk '{print $1}'`
      if [[ $is_mail_warning -eq 1 ]]; then
        mail_note $email_title "通知" "<p>服务器IP：${host_ip}<br>备份文件：${backup_filename}<br>文件大小：${backup_filesize}<br>备份目录：${backup_dir}<br>磁盘使用率
：${disk_use}<br>备份开始时间：${back_begin_time}<br>备份结束时间：${back_end_time}</p>"
      fi
      if [[ $is_dingding_warning -eq 1 ]]; then
        dingding_note $msg_title "通知" "\n* 服务器IP：${host_ip}\n* 备份文件：${backup_filename}\n* 文件大小：${backup_filesize}\n* 备份目录：${backup_dir}\n* 磁盘使用
率：${disk_use}\n* 备份开始时间：${back_begin_time}\n* 备份结束时间：${back_end_time}"
      fi

    fi
}

# 执行压缩备份
do_compress_backup()
{
    back_begin_time=`date "+%Y-%m-%d %H:%M:%S"`
    # 备份语句
    ${xtrabackup_path} --defaults-file=${mysql_cnf} --socket=${mysql_sock} --backup --user=${user} --password=${pwd} --target-dir=${target_dir_full}_${back_day} --parallel=4 --compress --compress-threads=4 > ${log_dir_full}.${back_day} 2>&1
    if [[ $? -ne 0 ]]; then
      if [[ $is_mail_warning -eq 1 ]]; then
        mail_note $email_title "异常" "<p>服务器IP：${host_ip}<br></p><h2>Mysql备份异常，请检查!</h2>"
      fi
      if [[ $is_dingding_warning -eq 1 ]]; then
        dingding_note $msg_title "异常" "\n* 服务器IP：${host_ip}\n* Mysql备份异常，请检查!"
      fi
    else
      back_end_time=`date "+%Y-%m-%d %H:%M:%S"`
      backup_filename=`ls ${backup_dir} | grep ${back_day}`
      backup_filesize=`du -sh ${backup_dir}/${backup_filename}|awk '{print $1}'`
      if [[ $is_mail_warning -eq 1 ]]; then
        mail_note $email_title "通知" "<p>服务器IP：${host_ip}<br>备份文件：${backup_filename}<br>压缩文件大小：${backup_filesize}<br>备份目录：${backup_dir}<br>磁盘使用率：${disk_use}<br>备份开始时间：${back_begin_time}<br>备份结束时间：${back_end_time}</p>"
      fi
      if [[ $is_dingding_warning -eq 1 ]]; then
        dingding_note $msg_title "通知" "\n* 服务器IP：${host_ip}\n* 备份文件：${backup_filename}\n* 压缩文件大小：${backup_filesize}\n* 备份目录：${backup_dir}\n* 磁盘使用率：${disk_use}\n* 备份开始时间：${back_begin_time}\n* 备份结束时间：${back_end_time}"
      fi
    fi
}

# 执行远程备份
do_remote_backup()
{
  remote_begin_time=`date "+%Y-%m-%d %H:%M:%S"`
  # tar 压缩
  cd $backup_dir
  tar zcf $backup_filename.tar $backup_filename
  # 传输到远程服务器
  scp -qr ${target_dir_full}_${back_day}.tar $remote_user@$remote_ip:$remote_backup_dir
  if [[ $? -ne 0 ]]; then
      if [[ $is_mail_warning -eq 1 ]]; then
        mail_note $remote_msg_title "异常" "<h2>远程传输备份异常，请检查!</h2><p>服务器IP：${host_ip}<br>远程服务器IP：$remote_ip<br>远程服务存储路径：$remote_backup_dir</p>"
      fi
      if [[ $is_dingding_warning -eq 1 ]]; then
        dingding_note $remote_msg_title "异常" "### 远程传输备份异常，请检查!\n* 服务器IP：${host_ip}\n* 远程服务器IP：$remote_ip\n* 远程服务存储路径：$remote_backup_dir"
      fi
  else
      remote_end_time=`date "+%Y-%m-%d %H:%M:%S"`
      tar_filesize=`du -sh ${backup_dir}/${backup_filename}.tar|awk '{print $1}'`
      if [[ $is_mail_warning -eq 1 ]]; then
        mail_note $remote_msg_title "通知" "<p>本地服务器IP：${host_ip}<br>打包备份文件名称：${backup_filename}.tar<br>压缩包大小：${tar_filesize}<br>本地备份目录：${backup_dir}<br>本地磁盘使用率：${disk_use}<br>远程服务器IP：${remote_ip}<br>远程备份目录：${remote_backup_dir}<br>远程磁盘使用率：${remote_disk_use}<br>远程备份开始时间：${remote_begin_time}<br>远程备份结束时间：${remote_end_time}</p>"
      fi
      if [[ $is_dingding_warning -eq 1 ]]; then
        dingding_note $remote_msg_title "通知" "\n* 本地服务器IP：${host_ip}\n* 打包备份文件名称：${backup_filename}.tar\n* 压缩包大小：${tar_filesize}\n* 本地备份目录：${backup_dir}\n* 本地磁盘使用率：${disk_use}\n* 远程服务器IP：${remote_ip}\n* 远程备份目录：${remote_backup_dir}\n* 远程磁盘使用率：${remote_disk_use}\n* 远程备份开始时间：${remote_begin_time}\n* 远程备份结束时间：${remote_end_time}"
      fi
  fi
}

# 清除历史备份
his_backup_clean()
{
    find $backup_dir -name "xtra_*" -mtime +${save_days} -exec rm -rf {} \;
    find $backup_log_dir -type f -name 'log_*' -mtime +${save_days} -exec rm -rf {} \;
}


# 检查备份是否正在运行
is_running_check()
{
    # 检查后台是否有xtrabackup进程
    local process=`ps -ef | grep -v "grep" | grep ${xtrabackup_path} | wc -l`
    if [ ${process} -eq 0 ];then
      backup_environment_check
      his_backup_clean
      if [[ ${is_compress_backup} -eq 0 ]];then
          do_backup
      elif [[ ${is_compress_backup} -eq 1 ]]; then
          do_compress_backup
      fi
      # 远程传输备份
      echo ${is_remote_backup}
      if [[ ${is_remote_backup} -eq 1 ]];then
        do_remote_backup
      fi
    else
      if [[ $is_mail_warning -eq 1 ]]; then
        mail_note $email_title "异常" "<p>服务器IP：${host_ip}<br></p><h2>xtrabackupe备份进程已存在，无法再次执行备份操作，请查看！</h2>"
      fi
      if [[ $is_dingding_warning -eq 1 ]]; then
        dingding_note $msg_title "异常" "\n* 服务器IP：${host_ip}\n* xtrabackupe备份进程已存在，无法再次执行备份操作，请查看！"
      fi
    fi
}

is_running_check
