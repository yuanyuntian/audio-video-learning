                    nginx服务器搭建流媒体 
1.支持STMP,hls,http
2.安装服务器nginx
    1.利用工具Homebrew进行安装，如果自己的电脑是比较新的系统，那么Homebrew的安装命令可能出现新的变化，建议先卸载在进行安装：
       卸载：ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
       安装：ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
    2.安装nginx
        1.先clone nginx项目到本地
            命令：brew tap denji/homebrew-nginx
        2.成功后，进行下面命令
            命令：brew install nginx-full --with-rtmp-module
        3.启动,测试安装是否成功，在浏览器地址栏输入：http://localhost:8080 显示网页正常即可
            命令: nginx 
            
            
            
            
1 利用AudioUnit播放本地pcm文件(参考项目AUGraphPlayer)
2 实现播放暂停功能，获取文件信息
3 实现播放MP3和PCM功能
4 AudioUnit+AudioFile播放MP3和PCM，其中mp3需要进行格式转换
5 AudioUnit+AudioFile播放MP3和PCM，其中mp3不需要进行格式转换

        
        


