k=1;
n=28;
folder='D:\Work\Data\mp-quic-logs\video-rebuffering\';
global exp_name;
exp_name = 'app-delay-quic\';
file_name = 'playout_interruptions.csv';
global SAMPLE_TIME;
SAMPLE_TIME = 60;
%% =========== Load DATA ==============
scheds=["lowRTT","RR","redundant","nineTails"];
labels=["LowRTT","RoundRobin","Redundant","NineTails"];
rebuffering_freq={};
rebuffering_dur={};
for j = 1:length(scheds)
    sched=convertStringsToChars(scheds(j));
eval([sched '_rebuffer_data_freq=[];']);
eval([sched '_rebuffer_data_dur=[];']);
for i=k:n
    
    eval([sched '_rebuffer_data = dlmread(strcat(folder,"video-",num2str(i),"-", scheds(j),"-",exp_name,file_name));' ]);
    eval([sched '_rebuffer_data = filter_data(' sched '_rebuffer_data);']);
    eval([sched '_rebuffer_data_freq(i,1)=length(' sched '_rebuffer_data);']);
%     eval([sched '_rebuffer_data_dur=vertcat(' sched '_rebuffer_data_dur,' sched '_rebuffer_data(:,2));']);
    eval([sched '_rebuffer_data_dur(i,1)=sum(' sched '_rebuffer_data(:,2));']);
end
eval(['rebuffering_freq{length(rebuffering_freq)+1}=' sched '_rebuffer_data_freq;']);
eval(['rebuffering_dur{length(rebuffering_dur)+1}=' sched '_rebuffer_data_dur;']);

end
plotBox(labels,rebuffering_freq);
plotBox(labels,rebuffering_dur);



%% =========== FUNCTION ==============
function[filtered_data] = filter_data(data)
        global SAMPLE_TIME;
 
        filtered_data = data(data(:, 1) < SAMPLE_TIME, :);

end

function[] = plotBox(labels,latencies)
global exp_name;
col=@(x)reshape(x,numel(x),1);
boxplot2=@(C,varargin)boxplot(cell2mat(cellfun(col,col(C),'uni',0)),cell2mat(arrayfun(@(I)I*ones(numel(C{I}),1),col(1:numel(C)),'uni',0)),varargin{:});

figure

bp=boxplot2(latencies,'Notch','off','Labels',labels);
set(bp,'LineWidth',1.5);
ylabel('Latency (ms)');
title(strcat('MeanLatency-',exp_name));

end