%% ====== SET PARAMS ==========
k=2;
n=2;
folder='D:\Work\Data\mp-quic-logs\';
distribution_name = 'on5-off3';
global exp_name;
exp_name = 'app-delay-quic-c-10-c-120000';
log_surfix= '-timestamp.log';
pcap_surfix= '-pcap.dat';
frame_log_surfix= '-frame.log';
HAS_PCAP = false;
HAS_FRAME_LOG = false;

global RTT; RTT=1;
global TIME_RESOLUTION; TIME_RESOLUTION = .1;

set(0,'DefaultFigureWindowStyle','docked');
set(0,'DefaultLineLineWidth',1.5);
set(0,'DefaultAxesXGrid','off','DefaultAxesYGrid','on','DefaultAxesGridLineStyle','--');
set(0,'defaultAxesPlotboxAspectRatio',[1.618,1,1]);
set(0,'defaultAxesPlotboxAspectRatioMode','manual');
set(0,'DefaultFigureColormap',feval('colorcube'));

%% =========== Load DATA ==============
scheds=["lrtt","rr","opp","nt"];
labels=["lrtt","rr","opp","nt"];

app_latencies={};
send_latencies={};
recv_latencies={};
net_latencies={};
server_dat={};
for j = 1:length(scheds)
    sched_app_latency=[];
    sched_send_latency=[];
    sched_recv_latency=[];
    sched_net_latency=[];
    for i=k:n
        
        
        
        sched=convertStringsToChars(scheds(j));
        eval([sched '_client_dat = dlmread(strcat(folder,num2str(i),"-", scheds(j),"-",exp_name, "-client",log_surfix ));' ]);
        eval([sched '_server_dat = dlmread(strcat(folder,num2str(i),"-", scheds(j),"-",exp_name, "-server",log_surfix ));' ]);
                 eval([sched '_client_dat = sortrows(' sched '_client_dat,1);']);
                 eval([sched '_server_dat = sortrows(' sched '_server_dat,1);']);
        %          eval(['sched_latency = vertcat(sched_latency, ' sched '_server_dat(:,2) - ' sched '_client_dat(:,2));'] );
        %          eval(['server_dat{j} = sortrows(' sched '_server_dat,2)/10^9;']);
        
        
        %     sched_latencies{length(sched_latencies)+1} = sched_latency/10^6;
        eval(['[~, row1, row2] = intersect(' sched '_client_dat(:,1),' sched '_server_dat(:,1),"sorted");']);
        eval([sched '_all_timestp = [' sched '_client_dat(row1,[1,2]), ' sched '_server_dat(row2,2)];']);
        eval([sched '_all_timestp(:,[2,3]) = ' sched '_all_timestp(:,[2,3]);']);
        
        
        
        pcap_labels=[];
        %% ====== Load pcap ==========
        if HAS_PCAP
            pcap_labels=["lrtt-pcap","rr-pcap","opp-pcap","re-pcap"];
            
            eval([sched '_pcap_dat = dlmread(strcat(folder,num2str(i),"-", scheds(j),"-",exp_name,pcap_surfix ));' ]);
            %             eval(['sched_latency = vertcat(sched_latency, ' sched '_pcap_dat(100:end-100,10));'] );
            
            eval([sched '_pcap_dat = sortrows(' sched '_pcap_dat,12);']);
            %         sched_latencies{length(sched_latencies)+1} = sched_latency*10^3;
            eval(['[~, row1, row2] = intersect(' sched '_all_timestp(:,1),' sched '_pcap_dat(:,12),"sorted");']);
            eval([sched '_all_timestp = [' sched '_all_timestp(row1,[1,2,3]), ' sched '_pcap_dat(row2, [6,7])];']);
            eval([sched '_all_timestp(:,[4,5]) = ' sched '_all_timestp(:,[4,5])*10^9;']);
            
            % calculating all delays
            %     for j = 1:length(scheds)
            %         sched=convertStringsToChars(scheds(j));
            %         eval(['[~, row1, row2] = intersect(' sched '_client_dat(:,1),' sched '_pcap_dat(:,12));']);
            %         eval(['temp = [' sched '_client_dat(row1,[1,2]), ' sched '_pcap_dat(row2, [6,7])];']);
            %         eval(['[~, row1, row2] = intersect(temp(:,1),' sched '_server_dat(:,1));']);
            %         eval([sched '_all_timestp = [temp(row1,[1,2,3,4]), ' sched '_server_dat(row2, 2)];']);
            %         eval([sched '_all_timestp(:,[3,4])=' sched '_all_timestp(:,[3,4])*10^3']);
            %         eval([sched '_all_timestp(:,[2,5])=' sched '_all_timestp(:,[2,5])/10^6']);
            %
            %
            %     end
                    eval(['sched_net_latency = vertcat(sched_net_latency,10^9*(' sched '_pcap_dat(:,7) - ' sched '_pcap_dat(:,6)));']);
        end
        
        %% ====== Load quic frame log ==========
        if HAS_FRAME_LOG
            pcap_labels=["lrtt-frame","rr-frame","opp-frame","nt-frame"];
            eval([sched '_frame_sender_dat = dlmread(strcat(folder,num2str(i),"-", scheds(j),"-",exp_name,"-sender",frame_log_surfix ));' ]);
            eval([sched '_frame_receiver_dat = dlmread(strcat(folder,num2str(i),"-", scheds(j),"-",exp_name,"-receiver",frame_log_surfix ));' ]);
            
            eval([sched '_frame_sender_dat = removeRedundantFrame(' sched '_frame_sender_dat);']);
            eval([sched '_frame_receiver_dat = removeRedundantFrame(' sched '_frame_receiver_dat);']);
            
            eval(['[~, row1, row2] = intersect(' sched '_frame_sender_dat(:,4),' sched '_frame_receiver_dat(:,4),"sorted");']);
            eval([sched '_frame_timestp = [' sched '_frame_sender_dat(row1,[5,4,6]), ' sched '_frame_receiver_dat(row2, [6])];']);
            
            eval(['[~, row1, row2] = intersect(' sched '_all_timestp(:,1),' sched '_frame_timestp(:,1),"sorted");']);
            eval([sched '_all_timestp = [' sched '_all_timestp(row1,[1,2,3]), ' sched '_frame_timestp(row2, [3,4])];']);
            eval(['sched_net_latency = vertcat(sched_net_latency,' sched '_all_timestp(:,5) - ' sched '_all_timestp(:,4));']);
        end
        
        
%         eval(['sched_app_latency = vertcat(sched_app_latency,' sched '_all_timestp(:,3) - ' sched '_all_timestp(:,2));']);
%         eval(['sched_send_latency = vertcat(sched_send_latency,' sched '_all_timestp(:,4) - ' sched '_all_timestp(:,2));']);
%         eval(['sched_recv_latency = vertcat(sched_recv_latency,' sched '_all_timestp(:,3) - ' sched '_all_timestp(:,5));']);
%         eval(['sched_net_latency = vertcat(sched_net_latency,' sched '_all_timestp(:,5) - ' sched '_all_timestp(:,4));']);
        %         eval(['sched_net_latency = vertcat(sched_net_latency,10^3*(' sched '_pcap_dat(:,7) - ' sched '_pcap_dat(:,6)));']);

        eval(['sched_app_latency = vertcat(sched_app_latency,' sched '_all_timestp(:,3) - ' sched '_all_timestp(:,2));']);
%         eval(['sched_send_latency = vertcat(sched_send_latency,' sched '_all_timestp(:,4) - ' sched '_all_timestp(:,2));']);
%         eval(['sched_recv_latency = vertcat(sched_recv_latency,' sched '_all_timestp(:,5) - ' sched '_all_timestp(:,2));']);
%         eval(['sched_net_latency = vertcat(sched_net_latency,' sched '_all_timestp(:,5) - ' sched '_all_timestp(:,4));']);
        

    end
    
    app_latencies{length(app_latencies)+1} = sched_app_latency/10^6;
    send_latencies{length(send_latencies)+1} = sched_send_latency/10^6;
    recv_latencies{length(recv_latencies)+1} = sched_recv_latency/10^6;
    net_latencies{length(net_latencies)+1} = sched_net_latency/10^6;
end

%% =========== plot DATA ==============
% latency_ana_label=["Dnet","Dnet + Dsnd","Dnet + Dsnd + Drecv"];
plotccdf([labels,pcap_labels],[app_latencies,net_latencies]);
% plotccdf([labels,pcap_labels],[send_latencies,recv_latencies]);
% plotccdf(latency_ana_label, [net_latencies(1), recv_latencies(1),app_latencies(1)]);
% plotccdf(latency_ana_label, [net_latencies(2), recv_latencies(2),app_latencies(2)]);
% plotccdf(latency_ana_label, [net_latencies(3), recv_latencies(3),app_latencies(3)]);
% plotccdf(latency_ana_label, [net_latencies(4), recv_latencies(4),app_latencies(4)]);
% plotccdf(latency_ana_label, [net_latencies(2), addCell(net_latencies(2),send_latencies(2)), addCell(net_latencies(2),send_latencies(2),recv_latencies(2)), send_latencies(2)]);
% plotccdf(latency_ana_label, [net_latencies(1), addCell(net_latencies(3),send_latencies(3)), addCell(net_latencies(3),send_latencies(3),recv_latencies(3)), send_latencies(3)]);
% plotccdf(latency_ana_label, [net_latencies(1), addCell(net_latencies(4),send_latencies(4)), addCell(net_latencies(4),send_latencies(4),recv_latencies(4)), send_latencies(4)]);
plot_throughput(labels,server_dat);
% plot_subflows("opp",opp_pcap_dat);
% plot_subflows("RR",rr_pcap_dat);
% plot_subflows("tag9999999",tag0_pcap_dat);



%% =========== Functions Definition ==============
function[sorted_data] = sortData(raw_data)
sorted_data = sortrows(raw_data,1);
end

function[]=plotccdf(labels,data)
global exp_name;

figure
for i=1:length(data)
    [xccdf,yccdf]=getccdf(data{i});
    plot(xccdf,yccdf);
    hold on;
end

xlabel('Latency (ms)') ;
ylabel('Probability P(X>x)');
title(strcat('CCDF-',exp_name));
legend(labels);
set(gca, 'YScale', 'log');
end

function[xccdf,yccdf] = getccdf(value)
[ycdf,xcdf] = cdfcalc(value);
xccdf = xcdf;
yccdf = 1-ycdf(1:end-1);

end

function[] = plot_throughput(labels,timestamp_data)
throughputs=[];
group = [];


for i=1:length(timestamp_data)
    figure
    thoughput=get_throughput(timestamp_data{i});
    throughputs=[throughputs;thoughput(:,2)];
    group=[group;i*ones(size(thoughput(:,2)))];
    plot(thoughput);
    hold on;
    legend(labels(i));
end

% boxplot(throughputs,group);

%set(gca,'XTickLabel',labels);
end

function[thoughput]=get_throughput(sched_dat)
global TIME_RESOLUTION;
TIME_COLUMM =6;
start_point = sched_dat(1,TIME_COLUMM);
end_point=sched_dat(end,TIME_COLUMM) ;
time_window= end_point - start_point;
thoughput = zeros(ceil(time_window)/TIME_RESOLUTION,2);

for i=1:size(thoughput)
    thoughput(i,1) = (i*TIME_RESOLUTION);
    
end

for i=1:size(sched_dat)
    relative_time = (sched_dat(i,TIME_COLUMM) - start_point)/TIME_RESOLUTION;
    thoughput(floor(relative_time)+1,2) = thoughput(floor(relative_time)+1,2)+ sched_dat(i,11)*8/TIME_RESOLUTION;
end

% trim the results
% thoughput = thoughput(20:end-20,:);
end

function[] = plot_subflows(plot_title,flow_data)

[sf_group,sf_senders] = findgroups(flow_data(:,3));
sf_throughput = splitapply(@(x){(get_throughput(x))},flow_data,sf_group);
figure
for i=1:size(sf_throughput(:,1))
    plot(sf_throughput{i,1}(:,1), sf_throughput{i,1}(:,2));
    hold on;
end
legend(dec2ip(sf_senders));

%     flow_throughput=get_throughput(flow_data);
%     plot(flow_throughput(:,1), flow_throughput(:,2));
%     hold on;
%     legend("All");


title(plot_title);

end
function[ip] = dec2ip(decip)
ip= strcat( num2str(bitand(bitshift(decip,-24), 255)) ,'.', num2str(bitand(bitshift(decip,-16), 255)) ,'.', num2str(bitand(bitshift(decip,-8), 255))  ,'.', num2str(bitand(bitshift(decip,0), 255)));
end

function[total] = addCell(varargin)
total=zeros(length(varargin{1}));
for i=1:nargin
    total = total + varargin{i}{1}(:,1);
end
end

function[frame_data] = removeRedundantFrame(data)
frame_data=[];
sorted_data = sortrows(data,4);
current_offset = 0;
first_sent = intmax;
first_sent_index =0;
for i=1:length(sorted_data)
    
    if 0 == sorted_data(i,1) || 1 == sorted_data(i,3)
        continue;
    end
    
    if current_offset ~= sorted_data(i,4) 
        frame_data(size(frame_data,1)+1,:) = sorted_data(i,:);
        first_sent_index = size(frame_data,1);
    elseif sorted_data(i,6) < first_sent
        frame_data(first_sent_index,:) = sorted_data(i,:);
        first_sent_index = size(frame_data,1);
    end
    
    
    
    current_offset = sorted_data(i,4);
end


end