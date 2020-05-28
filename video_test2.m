v = VideoWriter('test.avi');
open(v);

I = imread('waves.jpg');
I = double(imresize(I, 0.15)) / 255;
[h,w,~] =  size(I);

start_bits = [1,1,1,1,0,0];
bits = [0,0,0,1,0,1,0,0,1,0,1,1,0,0,1,0,0,1,1,1];
del = 0.9;

send_bits = cat(2,start_bits,bits);
for i = 1:length(send_bits)
   if send_bits(i) == 0
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,I)
   else
       writeVideo(v,del*I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,I)
       writeVideo(v,del*I)
       writeVideo(v,del*I)
       writeVideo(v,I)
       writeVideo(v,I)
   end
end

close(v)



close all
h = implay("test.avi", 20);

set(findall(0,'tag','spcui_scope_framework'),'position',[0 0 1300 800]);
set(0,'showHiddenHandles','on')
fig_handle = gcf ;  
fig_handle.findobj; 
ftw = fig_handle.findobj ('TooltipString', 'Maintain fit to window');  
ftw.ClickedCallback();  

play(h.DataSource.Controls);