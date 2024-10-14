%%
clear;
clc;
close all;

Data = AliconaReader(); %il faut séléctionner les données à traiter
%texture = Data.TextureData; (Image en RGB) 
%depth = Data.DepthData; (la hauteur de chaque point)
%quality = Data.QualityMap; (la zone de confiance des mesures en netty (leszones blanches sont peu fleux))
%header = Data.Header ;
%icon = Data.Icon; (la petite icone de l'image Texture (150*150))
AliconaPlot(Data) %affichage des resultats 

%% Plot unfiltred DepthData

%Calcul de la hauteur en um
Depth_um = Data.DepthData*1e3; 
%Interval des hauteurs 
clims = [min(Data.DepthData(:)) max(Data.DepthData(:))];  
%Afficher l'image avec des couleurs mises à l'échelle
imagesc(Depth_um,clims)
%Crée un tracé maillé, qui est une surface tridimensionnelle dont les couleurs des bords sont solides.
mesh(Depth_um)
colorbar


%% Plot filtered DepthData using filloutliers(Mad from the local median within a sliding window containing five elements.)

%Les valeurs aberrantes sont définies comme des éléments situés à plus de trois MAD (Median Absolute Deviation) de la médiane.
depth_inter_median = double(filloutliers(Depth_um,'nearest','median')); 
%Les valeurs aberrantes sont définies comme des éléments qui s'écartent de plus de trois écarts types de la moyenne. 
%Cette méthode est plus rapide mais moins robuste que la "médiane". Et Remplit avec la valeur non aberrante la plus proche
depth_inter_mean = double(filloutliers(Depth_um,'nearest','mean')); 
%interval des hauteurs
clims = [min(depth_inter_median(:)) max(depth_inter_median(:))];   
mesh(depth_inter_median)
colorbar
%Label axes
xlabel( 'X');
ylabel( 'Y');
zlabel( 'depth_inter_mean');

% Tester si il y a une différence entre 'median' et 'mean'
Test_median=depth_inter_median-depth_inter_mean;
max(Test_median(:));
min(Test_median(:));

Test= Depth_um-depth_inter_median;
%N=find(Test(:,:)!=0)
%Data.DepthData = depth_inter;
[X,Y] = meshgrid(1:1:1840);
%surf(X, Y, depth_inter)

%% Fit to get plane interpolation of the depthdata:
[xData, yData, zData] = prepareSurfaceData( X, Y, depth_inter_median ); %préparation des données à traiter avec fit Xdata, Ydata et Zdata en 1 seul colonne 
% Set up fittype and options.
ft = fittype( 'poly11' ); %Constrution des types d'ajustement en spécifiant des noms de modèles de bibliothèque, "poly11 = Surface polynomiale linéaire" .
% Fit model to data.
fitresult= fit( [xData, yData], zData, ft );
% Plot fit with data.
figure( 'Name', 'Depth_fit' );
%h = plot( fitresult, [xData, yData], zData );
hold on
mesh(depth_inter_median)
colorbar
h = plot( fitresult);
legend( h, 'Depth', 'depth vs. X, Y', 'Location', 'NorthEast', 'Interpreter', 'none' );
%Label axes
xlabel( 'X');
ylabel( 'Y');
zlabel( 'depth_Interpreter');
grid on
hold off

%% Dégauchissage du nuage de points

%Export les paramètres de l'équation du plane (Z = a*x + b*y + c)
paramtr=coeffvalues(fitresult); 
c=paramtr(1);
a=paramtr(2);
b=paramtr(3);
Z = a*X + b*Y + c;
%Calcule de la distance entre le plan et la surface obtenue
Distance=depth_inter_median-Z; 
%Génération d'un plan Horizontal
plan_Z_H=zeros(length(depth_inter_median)); 
%Nuage de points suive un plan horizontal passe par Z=0
Depth_data_H=plan_Z_H+Distance; 

hold on
%préparation des données à traiter avec fit Xdata, Ydata et Zdata en 1 seul colonne
[xData, yData, zData_H] = prepareSurfaceData( X, Y, Depth_data_H );  
fitresult_H= fit( [xData, yData], zData_H, ft);
h = plot( fitresult_H);
mesh(Depth_data_H)
%Label axes
xlabel( 'X');
ylabel( 'Y');
zlabel( 'Depth_data_H');
colorbar;

grid on
hold off

%% Algorithme de filtrage par convolution (Filtre median)
% % taille de filter c'est de nxn
% p=2; n=p*2+1; 
% % Ajouter des bords Ã  la matrice Depth_data_H ('both' pour ajouter p ligns et p colones dans les deux directions)
% matrice_base = padarray(Depth_data_H,[p p],0,'both');
% Z_Fmed = matrice_base;
% for i=p+1:length(matrice_base)-p
%     for j=p+1:length(matrice_base)-p
%         im0=matrice_base(i-p:i+p,j-p:j+p); % Extraction de l'imagette
%         V0=im0(:);                         % Conversion matrice => Tableau
%         V1=sort(V0);                       % Tri des valeurs du tableau (order croissace)
%         Im=round(n*n/2);                   % Indice Median dans le tableau V0
%         Med=V1(Im);                        % Extraction de la valeur median
%         Z_Fmed(i,j)=Med;                   % Affectation de la valeur au pixel de la matrice im_median
%     end
% end
% % Supression des bords ajoutés
% for n=1:p
%     Z_Fmed(1,:) = [];
%     Z_Fmed(length(Z_Fmed)-1,:) = [];
%     Z_Fmed(:,1) = [];
%     Z_Fmed(:,length(Z_Fmed)-1) = [];
% end
% % Affichage
% hold on
% mask = imregionalmax(Z_Fmed);
% mesh(Z_Fmed);
% plot3(X(mask), Y(mask), Z_Fmed(mask), 'r+')
% % Nombre de pics par unité d'aire.
% Sdk_FMed = length(find(mask(:,:)==1))/(str2double(Data.Header.PixelSizeYMeter)*length(Depth_data_H))^2

%% Filtrage Frequentiel
% TrnForier = fft2(Depth_data_H);
% Imfft2 = log(abs(fftshift(TrnForier))+1);
% figure,imshow(Imfft2,[]);
% H=ones(length(Depth_data_H),length(Depth_data_H));
% D=100;
% H(length(Depth_data_H)/2-D:length(Depth_data_H)/2+D, length(Depth_data_H)/2-D:length(Depth_data_H)/2+D)=0;
% figure,imshow(H);
% Imfft_F = log(abs(fftshift(TrnForier)).*H);
% figure,imshow(Imfft_F,[]);
% imfft_inv=ifft2((TrnForier).*(H));
% figure,imshow(abs(imfft_inv),[]);


%% Interfaces 
           switch item
                case 'Filtre de Gauss'
                    FiltGauss_Z = imgaussfilt(Depth_data_H,0.9,"FilterSize",3);
                    app.Sp =max(FiltGauss_Z(:));
                    app.Sv = min(FiltGauss_Z(:));
                    app.Sz = (abs(app.Sp) + abs(app.Sv))/(length(FiltGauss_Z)*str2double(app.Data.Header.PixelSizeYMeter))^2;
                    app.Sa = mean(mean(abs(FiltGauss_Z)));
                    app.Sq = sqrt(sum(sum(FiltGauss_Z.^2))/length(FiltGauss_Z)^2);
                    app.Ssk = mean(mean((FiltGauss_Z.^3)))/app.Sq^3 ;
                    app.Sku = mean(mean((FiltGauss_Z.^4)))/app.Sq^4;
                case 'Filtre moyenne'
                    filter = fspecial('average',[3 3]); 
                    FMoyenne_Z = imfilter(Depth_data_H,filter,'conv');
                    app.Sp =max(FMoyenne_Z(:));
                    app.Sv = min(FMoyenne_Z(:));
                    app.Sz = (abs(app.Sp) + abs(app.Sv))/(length(FMoyenne_Z)*str2double(app.Data.Header.PixelSizeYMeter))^2;
                    app.Sa = mean(mean(abs(FMoyenne_Z)));
                    app.Sq = sqrt(sum(sum(FMoyenne_Z.^2))/length(FMoyenne_Z)^2);
                    app.Ssk = mean(mean((FMoyenne_Z.^3)))/app.Sq^3 ;
                    app.Sku = mean(mean((FMoyenne_Z.^4)))/app.Sq^4;
            end







Data = AliconaReader(); %Lire les données
%Détecter et remplacer les données aberrantes
Z_Data = double(filloutliers(Data.DepthData,'nearest','median')); 
[X,Y] = meshgrid(1:1:length(Data.DepthData));
[xData, yData, zData] = prepareSurfaceData( X, Y, Z_Data ); %préparation des
% données à  traiter avec fit Xdata, Ydata et Zdata en 1 seul colonne 
% Configurer le fittype et les différentes paramètre.
ft = fittype( 'poly11' ); %Constrution des types d'ajustement en spécifiant
% le modéles, "poly11 = Surface polynomiale linéaire" .
% Ajustement du modèle aux données.
fitresult= fit( [xData, yData], zData, ft );
% affichage du plan avec les données. 
figure( 'Name', 'Depth_fit' );
hold on
mesh(Z_Data)
colorbar
h = plot( fitresult);
hold off

%%


%Sp : Hauteur du pic maximale de la surface 
Sp = max(Z_data_H(:));
%Sv : profondeur maximale de creux.
Sv = abs(min(Z_data_H(:)));
%Sz,Amplitude maximale de la surface.
Sz = Sp + Sv ;
%Rugosite moyenne arithmetique des hauteurs Z(x,y).
Sa = mean(mean(abs(Z_data_H)));
%Rugosite moyenne quadratique des valeurs des hauteurs Z (x, y).
Sq = sqrt(sum(sum(Z_data_H.^2))/length(Z_data_H)^2);
%Ssk : Facteur d'asymètrie de la surface 
Ssk = (mean(mean((Z_data_H.^3)))/Sq^3); 
%Sku : Facteur d'aplatissement de la furface
Sku = (mean(mean((Z_data_H.^4)))/Sq^4); 
mask = imregionalmax(Z_data_H);
% Sds : Nombre de pics par unite d'aire.
Sds = floor(length(find(mask(:,:)==1))/ ...
    (str2double(Data.Header.PixelSizeYMeter)*length(Z_data_H))^2);

