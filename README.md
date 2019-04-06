# simRiboSeq

| Module             	| Function                                                                      	| Input                                                                                                                                                                                                	| Output                                                                              	|
|--------------------	|-------------------------------------------------------------------------------	|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	|-------------------------------------------------------------------------------------	|
| simTranscriptome.R 	| genSequence()                                                                 	| - Number of codons in transcript<br>- Genomic codon distributions                                                                                                                                    	| Individual transcript codon sequence*                                               	|
|                    	| simTranscriptome()  * plus padding (6 codons for 5’ end, 4 codons for 3’ end) 	| - Transcript lengths (in codons) for all transcripts<br>- Genomic codon distributions                                                                                                                	| .fa file for transcriptome*                                                         	|
| simProfiles.R      	| simPi()                                                                       	| - Transcriptome* .fa file<br>- Transcript lengths from model experiment<br>- Transcript abundances from model experiment<br>- Model class for abundance ~ length (loess / linear regression)         	| Vector of probabilities of ribosome mapping to individual transcript                	|
|                    	| simRho()                                                                      	| - Transcriptome* .fa file<br>- Number of codons padding cds<br>- Translational efficiency of codon averaged over genome                                                                              	| Vector of probabilities of ribosome mapping to individual codon within a transcript 	|
|                    	| genRawProfiles()                                                              	| - Number of ribosomes<br>- \pi vector<br>- \rho vectors                                                                                                                                              	| Ribosome counts per codon per transcript                                            	|
|                    	| simProfiles()                                                                 	| [ wrapper function ]                                                                                                                                                                                 	| Simulated parameter values [format?] and rawProfiles.txt                            	|
| simFootprints.R    	| digest() - digest_transcript()                                                	| - Transcriptome* .fa file<br>- Ribosome counts (rawProfiles.txt)<br>- Probabilities for 5’ digest lengths<br>- Probabilities for 3’ digest lengths<br>- Minimum read length<br>- Maximum read length 	| Footprint sequences                                                                 	|
|                    	| getBiasRegion()                                                               	| - Footprint sequences<br>- Length of bias region                                                                                                                                                     	| Nucleotide sequence for bias region                                                 	|
|                    	| ligate()                                                                      	| - Footprint sequences<br>- Probabilities of successful ligation for bias regions                                                                                                                     	| Footprint sequences                                                                 	|
|                    	| circularize()                                                                 	| - Footprint sequences<br>- Probabilities of successful circularization for bias regions                                                                                                              	| Footprint sequences                                                                 	|
|                    	| simFootprints()                                                               	| [ wrapper function ]<br>- sequencing sampling loss                                                                                                                                                   	| .fa file for footprint sequences                                                    	|
| helper.R           	| readFAfile()                                                                  	|                                                                                                                                                                                                      	|                                                                                     	|
|                    	| readFAfile_multiline()                                                        	|                                                                                                                                                                                                      	|                                                                                     	|
|                    	| readRawProfiles()                                                             	|                                                                                                                                                                                                      	|                                                                                     	|
