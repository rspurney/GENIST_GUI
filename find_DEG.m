function find_DEG(mk_interest,mk_compare,mk,filename,q_th,FC_th,TF_file,symbol_file)

% Finds the genes that are differentially expressed and upregulated in the
% marker (sample) of interest compared to all other specified
% markers (samples). Names of the samples must be consistent with the names
% used in the gene_exp.diff file generated by Cuffdiff.
%
% To see the downregulated genes, switch the oreder of mk_interest and
% mk_compare.
%
%
% find_DEG_custom_GUI(mk_interest,mk_compare,mk,filename,q_th,FC_th)
% creates a table of DEG -default output name is 'DEG_*_vs_**.xlsx', where *
% refers to the sample(s) of interest, and ** refers to the sample(s) that
% we compare against. Genes selected as differentially expressed are those
% with FDR < q_th & log2fc < FC_th.
% In addition, a gene expression table, and a complete table (gene
% expression, q value and fold change) are generated and saved in the
% working directory.

%
% find_DEG_custom_GUI(mk_interest,mk_compare,mk,filename,q_th,FC_th,TF_file)
% creates an additional tab in the table of DEG containing information
% about the TFs only.

%
% find_DEG_custom_GUI(mk_interest,mk_compare,mk,filename,q_th,FC_th,TF_file,symbol_file)
% adds a column of information about each gene (gene name) in the table of DEG.

% Example 1:
% mk = {'T0','T1','T2'};
% mk_interest = {'T0'};
% mk_compare = {'T1','T2'};
% filename = 'gene_exp.txt';
% q_th = 0.05;
% FC_th = 2;
% find_DEG_custom_GUI(mk_interest,mk_compare,mk,filename,q_th,FC_th)

% Example 2:
% mk = {'T0','T1','T2'};
% mk_interest = {'T0'};
% mk_compare = {'T1','T2'};
% filename = 'gene_exp.txt';
% q_th = 0.05;
% FC_th = 2;
% symbol_file = 'gene_names.xlsx';
% find_DEG_custom_GUI(mk_interest,mk_compare,mk,filename,q_th,FC_th,[],symbol_file)

% Author:
% M. Angels de Luis Balaguer
% Postdoctoral Research Scholar
% North Carolina State University
% 2016


global symbol
global TF

if nargin < 6
    error('Not enough input arguments. Provide at least sample names, samples included in the comparison (sample_interest & sample_compare), output file from Cuffdiff, and FC & q value threshold for selecting differentially expressed genes.')
end

gene_exp = readtable(char(filename),'Delimiter','tab');

if ~exist('TF_file', 'var') || isempty(TF_file)
    TF = {};
else
    TF = dataset('XLSFile',char(TF_file),'ReadObsNames',false);
end

% Definition of variables
n_cond = length(mk);
n_comp_vect = 1:n_cond-1;
n_comp = sum(n_comp_vect);

% Find the number of genes that there are in the file
[fid, msg] = fopen(char(filename));
if fid < 0
    error('Failed to open file "%s" because "%s"', filename, msg);
end
n = 0;
while true
    t = fgetl(fid);
    if ~ischar(t)
        break;
    else
        n = n + 1;
    end
end
fclose(fid);
n_genes = (n-1)/n_comp;

if ~exist('symbol_file', 'var') || isempty(symbol_file)
    tmp(:,1)=gene_exp(1:n_genes,3);
    tmp(:,2)=gene_exp(1:n_genes,3);
    symbol = tmp;
    sym = table2cell(symbol);
else
    symbol = dataset('XLSFile',char(symbol_file),'ReadObsNames',false);
    sym = cellstr(symbol);
end

% Call the file that writes all the tables
create_DE_Table(mk,n_genes,q_th,FC_th,filename);

% Read the tables that were generated
DE_T = readtable('data_DE','Delimiter','tab');
exp_T = readtable('gene_expression.xlsx','Sheet',1);
complete_T = readtable('complete_table.xlsx','Sheet',1);

for comparison_direction = 1:2
    
    if comparison_direction == 2
        mk_interest_aux = mk_interest;
        mk_interest = mk_compare;
        mk_compare = mk_interest_aux;
    end
    
    c = 0;
    ind_comp1 = zeros(n_comp,1); % var to save the positions of the marker of interest in the list comparisions when it's in the first position ("mk vs. b")
    ind_comp2 = zeros(n_comp,1); % var to save the positions of the marker of interest in the list comparisions when it's in the first position ("mk vs. b") (yes, the first pos, because i just run the forward loop)
    
    for i = 1:n_cond-1 % loop to find the positions of the marker of interest in the list comparisions
        for j = i+1:n_cond
            c = c+1;
            ind_comp1(c) = ismember(mk(i),mk_interest) & ismember(mk(j),mk_compare);
            ind_comp2(c) = ismember(mk(j),mk_interest) & ismember(mk(i),mk_compare);
        end
    end
    
    ind_comp = [ind_comp1;ind_comp2];
    enrichment_cols = find(ind_comp);
    
    
    DE_T_values = table2array(DE_T(:,2:end));
    ID = table2cell(DE_T(:,1));
    
    DE_T_values = DE_T_values(:,enrichment_cols); % from the DE matrix, select only the columns corresponding to the zone of interest
    pattern = ones(size(enrichment_cols));
    ind_DE_genes = ismember(DE_T_values,pattern','rows')'; % find genes enriched in the columns of interest, NO MATTER HOW THE REST LOOK.
    
    DE_genes = ID(ind_DE_genes);
    
    DE_genes_info = cell(length(DE_genes),2);
    
    for j = 1:length(DE_genes)
        idx = ismember(sym(:,1),DE_genes(j));
        new_name = sym(idx,:);
        if isempty(new_name)
            DE_genes_info(j,1) = DE_genes(j);
        else
            DE_genes_info(j,:) = sym(idx,1:2);
        end
    end
    
    
    TF_vector = cellstr(TF); % Convert the dataset into a cell of arrays type
    TF_pos = ismember(DE_genes_info(:,1),TF_vector)'; % find TFs
    
    exp_T_values = table2array(exp_T(:,2:end));
    exp_DE_genes = exp_T_values(ind_DE_genes,:);
    
    DE_Table = complete_T(ind_DE_genes,2:end);
    
    Table_name = table(DE_genes_info(:,1),DE_genes_info(:,2));
    Table_name.Properties.VariableNames = {'gene','name'};
    DE_Table = [Table_name DE_Table];
    DE_TF_Table = DE_Table(TF_pos,:);
    
    filename_compare = mk_compare(1);
    if length(mk_compare) > 1
        for i = 2:length(mk_compare)
            filename_compare = char(strcat(filename_compare,'_',mk_compare(i)));
        end
    end
    
    filename_interest = mk_interest(1);
    if length(mk_interest) > 1
        for i = 2:length(mk_interest)
            filename_interest = char(strcat(filename_interest,'_',mk_interest(i)));
        end
    end
    
    filename = char(strcat('DEG_',filename_interest,'_vs_',filename_compare,'.xlsx'));
    writetable(DE_Table,filename,'Sheet','Genes');
    writetable(DE_TF_Table,filename,'Sheet','TFs');
end
end
