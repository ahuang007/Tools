#coding:utf-8
# 用来检测log中的TraceBack并发送邮件

import  os
import  smtplib
from    email.mime.text import MIMEText
from    email.header import Header
import  re
import  socket

#发送对象
mailto_list=[
    "andy@61games.hk",
]

mail_host       = "smtp.qq.com"
mail_user       = "419637330"
mail_pass       = "wqnecpxkaiobbjha" #ssl认证
mail_postfix    = "qq.com"

def send_mail(to_list,title,content):
    '''
    to_list :邮件地址列表
    title   :标题
    content :内容
    send_mail("xxx@qq.com","title","content")
    '''
    me = "%s<"%(Header('《美味战争》服务器警告邮件','utf-8')) + mail_user + "@" + mail_postfix+">"
    msg = MIMEText(content, format, 'utf-8')
    msg['Subject'] = title
    msg['From'] = me
    msg['To'] = ";".join(to_list)
    msg["Accept-Language"]="zh-CN"
    msg["Accept-Charset"]="ISO-8859-1,utf-8"
    try:
        s = smtplib.SMTP()
        s.connect(mail_host)
        s.starttls()
        s.login(mail_user,mail_pass)
        s.sendmail(me, to_list, msg.as_string())
        s.close()
        return True
    except Exception, e:
        print str(e)
        return False

#ip地址
ip          = "10.10.2.58"
#项目名
ProjectName = "美味战争"
#路径
logdir      = os.getcwd() + "/log"

is_send = False

##定时检测
for parent,dirnames,filenames in os.walk(logdir):    #三个参数：分别返回1.父目录 2.所有文件夹名字（不含路径） 3.所有文件名字
    for filename in filenames:                       #输出文件信息
        print "filename :" + filename

        #读取文件
        file_object = open(logdir + "/" + filename)

        last_line = ""
        try:
            for line in file_object:
                if re.match("stack traceback", line):
                    title       = filename
                    line_list   = [last_line, line]
                    next_line   = file_object.next()
                    while not re.match("^[", next_line):
                        line_list.append(next_line)
                        next_line = file_object.next()

                    content     = "\n".join(line_list)

                    if not is_send:
                        is_send = True
                        send_mail(mailto_list, title, content)

                last_line = line
        finally:
            file_object.close()

        #判断当天的
        #判断是否重复
        #发送邮件
