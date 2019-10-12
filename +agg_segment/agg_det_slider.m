
% AGG_DET_SLIDER Semi-automatic detection of the aggregates on TEM images
% 
% This function applies background correction and thresholding on the
% user-defined portion of the image.
% 
% Function to be used with the Pair Correlation Method (PCM) package
%
% Author:       Ramin Dastanpour, Steven N. Rogak, 2016-02 (originally)
% Developed at the University of British Columbia
%
% Edited by:    Timothy Sipkens, 2019-10-11
%=========================================================================%

function [img_binary,rect,thresh_slider_in,img_cropped] = agg_det_slider(img,bool_crop) 

%== Parse input ==========================================================%
if ~exist('bool_crop','var'); bool_crop = []; end
if isempty(bool_crop); bool_crop = 1; end


img_binary_4 = []; % declare nested variable


%-- Crop image ----------------------%
if bool_crop
    uiwait(msgbox('Please crop the image around missing particle'));
    [img_cropped, rect] = imcrop(img); % user crops image
else
	img_cropped = img; % originally bypassed in Kook code
    rect = [];
end

%== Step 1: Image refinment ==============================================%
%-- Step 1-1: Apply Lasso tool -------------------------------------------%
img_binary = lasso_fnc(img_cropped);

%-- Step 1-2: Refining background brightness -----------------------------%
img_refined = background_fnc(img_binary,img_cropped);


%== Step 2: Thresholding =================================================%
thresh_slider_in = img_refined;
f = figure;
screen_size = get(0,'Screensize');
set(gcf,'Position',screen_size); % maximize figure

% axis_size = round(0.7*min(screen_size(3:4)));
% hax = axes('Units','Pixels','Position',...
%     [min(screen_size(3:4)-100-axis_size),...
%     50,axis_size,axis_size]);
hax = axes('Units','Pixels');
imshow(thresh_slider_in);

level = graythresh(thresh_slider_in);
hst = uicontrol('Style', 'slider',...
    'Min',0-level,'Max',1-level,'Value',.5-level,...
    'Position', [20 390 150 15],...
    'Callback', {@thresh_slider,hax,thresh_slider_in,img_binary});
get(hst,'value'); % add a slider uicontrol

uicontrol('Style','text',...
    'Position', [20 370 150 15],...
    'String','Threshold level');
        % add a text uicontrol to label the slider

%-- Pause program while user changes the threshold level -----------------%
h = uicontrol('Position',[20 320 200 30],'String','Finished',...
    'Callback','uiresume(gcbf)');
message = sprintf('Move the slider to the right or left to change threshold level\nWhen finished, click on continute');
uiwait(msgbox(message));
disp('Waiting for the user to apply the threshold to the image');
uiwait(gcf);
close(gcf);
disp('Thresholding is applied.');

%-- Select particles and format output -----------------------------------%
uiwait(msgbox('Please selects (left click) particles satisfactorily detected; and press enter'));
img_binary = bwselect(img_binary_4,8);
close(gcf);
img_binary = ~img_binary; % formatted for PCA, other codes should reverse this





%=========================================================================%
%== BACKGROUND_FNC =======================================================%
% Smooths out background using curve fitting
% Originally by:    Ramin Dastanpour, Steven N. Rogak, Last updated in Feb. 2016
% Modified by:      Timothy Sipkens, 2019-07-16
%
% Notes:
%   This function smoothens background brightness, specially on the edges of
%   the image where intensity (brightness) has a curved planar distribution.
%   This improves thresholding in the following steps of image processing

function img_refined = background_fnc(img_binary,img_cropped)

nagg = nnz(img_binary); % pixels within the aggregate
ntot = numel(img_cropped); % pixels within the whole cropped image 
nbg = ntot-nagg; % pixels in the backgound of the aggregate


%-- Computing average background intensity -------------------------------%
burned_img = img_cropped;
burned_img(img_binary) = 0;
mean_bg =  mean(mean(burned_img))*ntot/nbg;


%-- Replace aggregate pixels' with intensity from the background ---------%
img_bg = img_cropped;
img_bg(img_binary) = mean_bg;


%-- Fit a curved surface into Filled_img data ----------------------------%
[x_d,y_d] = meshgrid(1:size(img_bg,2),1:size(img_bg,1));
xdata = {x_d,y_d};
fun = @(c,xdata) c(1).*xdata{1}.^2+c(2).*xdata{2}.^2+c(3).*xdata{1}.*xdata{2}+...
    c(4).*xdata{1}+c(5).*xdata{2}+c(6);

c_start = [0 0 0 0 0 mean_bg];
options = optimset('MaxFunEvals',1000);
options = optimset(options,'MaxIter',1000); 
[c] = lsqcurvefit(fun,c_start,xdata,double(img_bg),[],[],options);


%-- Build the fitted surface ---------------------------------------------%
img_bg_fit = zeros(size(img_bg));
for ii = 1:size(img_bg,1)
    for jj = 1:size(img_bg,2)
        img_bg_fit(ii,jj) = ...
            c(1)*ii^2+c(2)*jj^2+c(3)*ii*jj+c(4)*ii+c(5)*jj+c(6);
    end
end


%-- Refine Cropped_img, using fitted surface -----------------------------%
img_refined = mean_bg+double(img_cropped)-img_bg_fit;
img_refined = uint8(img_refined);

end




%=========================================================================%
%== LASSO_FNC ============================================================%
% Semi-automatic detection of the aggregates on TEM images
% Function to be used with the Pair Correlation Method (PCM) package
% Ramin Dastanpour & Steven N. Rogak
% Developed at the University of British Columbia
% This function allows user to draw an approximate boundary around the
% particle. Region of interest (ROI))

% Updated by Yiling Kang on May. 10, 2018
% Updates/QOL Changes:
%   - Asks user if their lasso selection is correct before applying the
%     data
%   - QOL - User will not have to restart program if they mess up the lasso

function binaryImage = lasso_fnc(Cropped_im)

fontsize = 10;

%-- Displaying cropped image ---------------------------------------------%
figure; imshow(Cropped_im);
title('Original CROPPED Image', 'FontSize', fontsize);
set(gcf, 'Position', get(0,'Screensize')); % Maximize figure.

%-- Freehand drawing. Selecting region of interest (ROI) -----------------%
drawing_correct = 0; % this variable is used to check if the user drew the lasso correctly
while drawing_correct == 0 
    message = sprintf('Please draw an approximate boundary around the aggregate.\nLeft click and hold to begin drawing.\nLift mouse button to finish');
    uiwait(msgbox(message));
    hFH = imfreehand(); 
    finished_check = questdlg('Are you satisfied with your drawing?','Lasso Complete?','Yes','No','No');
    
    % if user is happy with their selection...
    if strcmp(finished_check, 'Yes')
        drawing_correct = 1;
    % if user would like to redo their selection...
    else
        delete(hFH);
    end     
end


%-- Create a binary masked image from the ROI object ---------------------%
binaryImage = hFH.createMask();


end





%=========================================================================%
%== THRESH_SLIDER ========================================================%
% Thresholding the image as a part of semi-automatic particle detection
% Function to be used with the Pair Correlation Method (PCM) package
% Ramin Dastanpour & Steven N. Rogak
% Developed at the University of British Columbia
% Last updated in Feb. 2016
% Slider method

function thresh_slider(hObj,event,hax,thresh_slider_in,binaryImage) %#ok<INUSL>

%-- Average filter -------------------------------------------------------%
hav = fspecial('average');
img_filtered = imfilter(thresh_slider_in, hav);


%-- Median ---------------------------------------------------------------%
% Examines a neighborhood of WxW matrix, takes and makes the centre of that
% matrix the median of the original neighborhood
W = 5;
thresh_slider_in = medfilt2(img_filtered,[W W]);


%-- Binary image via threshold value -------------------------------------%
adj = get(hObj,'Value');
level = graythresh(thresh_slider_in);
level = level+adj;
img_binary1 = imbinarize(thresh_slider_in,level);


%-- Binary image via dilation --------------------------------------------%
%   Reduces initial noise and fill initial gaps
SE1 = strel('square',1);
img_binary2 = imdilate(~img_binary1,SE1);


%-- Refining binary image. Before refinig, thresholding causes some ------%
%   Errors, initiating from edges, grows towards the aggregate. In
%   this section, external boundary, or background region, is utilized to
%   eliminate detection errors in the background region.
img_binary3 = 0.*img_binary2;
img_binary3(binaryImage) = img_binary2(binaryImage);
img_binary_4 = logical(img_binary3);

img_temp2 = imimposemin(thresh_slider_in,img_binary_4);

axes(hax);
% cla;
imshow(img_temp2);

end


end