/*--------------------------------------------------------------------
 *	$Id$
 *
 *	Copyright (c) 1991-2012 by P. Wessel, W. H. F. Smith, R. Scharroo, and J. Luis
 *	See LICENSE.TXT file for copying and redistribution conditions.
 *
 *	This program is free software; you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation; version 2 or any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	Contact info: gmt.soest.hawaii.edu
 *--------------------------------------------------------------------*/
/*
 * Brief synopsis: grd2xyz.c reads a grid file and prints out the x,y,z values to
 * standard output.
 *
 * Author:	Paul Wessel
 * Date:	1-JAN-2010
 * Version:	5 API
 */

#include "gmt.h"

struct GRD2XYZ_CTRL {
#ifdef GMT_COMPAT
	struct E {	/* -E[f][<nodata>] */
		GMT_LONG active;
		GMT_LONG floating;
		double nodata;
	} E;
#endif
	struct N {	/* -N<nodata> */
		GMT_LONG active;
		double value;
	} N;
	struct W {	/* -W[<weight>] */
		GMT_LONG active;
		double weight;
	} W;
	struct GMT_PARSE_Z_IO Z;
};

void *New_grd2xyz_Ctrl (struct GMT_CTRL *GMT) {	/* Allocate and initialize a new control structure */
	struct GRD2XYZ_CTRL *C;
	
	C = GMT_memory (GMT, NULL, 1, struct GRD2XYZ_CTRL);
	
	/* Initialize values whose defaults are not 0/FALSE/NULL */
	
#ifdef GMT_COMPAT
	C->E.nodata = -9999.0;
#endif
	C->W.weight = 1.0;
	C->Z.type = 'a';
	C->Z.format[0] = 'T';	C->Z.format[1] = 'L';
		
	return (C);
}

void Free_grd2xyz_Ctrl (struct GMT_CTRL *GMT, struct GRD2XYZ_CTRL *C) {	/* Deallocate control structure */
	GMT_free (GMT, C);	
}

GMT_LONG GMT_grd2xyz_usage (struct GMTAPI_CTRL *C, GMT_LONG level) {
	struct GMT_CTRL *GMT = C->GMT;

	GMT_message (GMT, "grd2xyz %s [API] - Convert grid file to data table\n\n", GMT_VERSION);
	GMT_message (GMT, "usage: grd2xyz <grid> [-N<nodata>] [%s] [%s]\n", GMT_Rgeo_OPT, GMT_V_OPT);
	GMT_message (GMT, "\t[-W[<weight>]] [-Z[<flags>]] [%s] [%s] [%s]\n\t[%s] [%s] [%s] > xyzfile\n",
		GMT_bo_OPT, GMT_f_OPT, GMT_ho_OPT, GMT_o_OPT, GMT_s_OPT, GMT_colon_OPT);

	if (level == GMTAPI_SYNOPSIS) return (EXIT_FAILURE);

	GMT_message (GMT, "\n\t<grid> is one or more grid files.\n");
	GMT_message (GMT, "\n\tOPTIONS:\n");
	GMT_message (GMT, "\t-N Replace z-values that equal NaN with this value [Default writes NaN].\n");
	GMT_explain_options (GMT, "RV");
	GMT_message (GMT, "\t-W Write xyzw using supplied weight (or 1 if not given) [Default is xyz].\n");
	GMT_message (GMT, "\t-Z Set exact specification of resulting 1-column output z-table.\n");
	GMT_message (GMT, "\t   If data is in row format, state if first row is at T(op) or B(ottom).\n");
	GMT_message (GMT, "\t     Then, append L or R to indicate starting point in row.\n");
	GMT_message (GMT, "\t   If data is in column format, state if first columns is L(left) or R(ight).\n");
	GMT_message (GMT, "\t     Then, append T or B to indicate starting point in column.\n");
	GMT_message (GMT, "\t   Append x if gridline-registered, periodic data in x without repeating column at xmax.\n");
	GMT_message (GMT, "\t   Append y if gridline-registered, periodic data in y without repeating row at ymax.\n");
	GMT_message (GMT, "\t   Specify one of the following data types (all binary except a):\n");
	GMT_message (GMT, "\t     a  Ascii.\n");
	GMT_message (GMT, "\t     c  signed 1-byte character.\n");
	GMT_message (GMT, "\t     u  unsigned 1-byte character.\n");
	GMT_message (GMT, "\t     h  signed short 2-byte integer.\n");
	GMT_message (GMT, "\t     H  unsigned short 2-byte integer.\n");
	GMT_message (GMT, "\t     i  signed 4-byte integer.\n");
	GMT_message (GMT, "\t     I  unsigned 4-byte integer.\n");
	GMT_message (GMT, "\t     l  long (4- or 8-byte) integer.\n");
	if (sizeof (GMT_LONG) == 8) {
		GMT_message (GMT, "\t     l  signed long (8-byte) integer.\n");
		GMT_message (GMT, "\t     L  unsigned long (8-byte) integer.\n");
	}
	GMT_message (GMT, "\t     f  4-byte floating point single precision.\n");
	GMT_message (GMT, "\t     d  8-byte floating point double precision.\n");
	GMT_message (GMT, "\t   [Default format is scanline orientation in ascii representation: -ZTLa].\n");
	GMT_explain_options (GMT, "D0fhos:.");
	
	return (EXIT_FAILURE);
}

GMT_LONG GMT_grd2xyz_parse (struct GMTAPI_CTRL *C, struct GRD2XYZ_CTRL *Ctrl, struct GMT_Z_IO *io, struct GMT_OPTION *options) {

	/* This parses the options provided to grdcut and sets parameters in CTRL.
	 * Any GMT common options will override values set previously by other commands.
	 * It also replaces any file names specified as input or output with the data ID
	 * returned when registering these sources/destinations with the API.
	 */

	GMT_LONG n_errors = 0, n_files = 0;
	struct GMT_OPTION *opt = NULL;
	struct GMT_CTRL *GMT = C->GMT;

	GMT_memset (io, 1, struct GMT_Z_IO);
	
	for (opt = options; opt; opt = opt->next) {	/* Process all the options given */

		switch (opt->option) {
			case '<':	/* Input files */
				n_files++;
				break;
				
			/* Processes program-specific parameters */

#ifdef GMT_COMPAT
			case 'E':	/* Old ESRI option */
				Ctrl->E.active = TRUE;
				GMT_report (GMT, GMT_MSG_COMPAT, "Warning: Option -E is deprecated; use grdreformat instead.\n");
				if (opt->arg[0] == 'f') Ctrl->E.floating = TRUE;
				if (opt->arg[Ctrl->E.floating]) Ctrl->E.nodata = atof (&opt->arg[Ctrl->E.floating]);
				break;
			case 'S':	/* Suppress/no-suppress NaNs on output */
				GMT_report (GMT, GMT_MSG_COMPAT, "Warning: Option -S is deprecated; use -s instead.\n");
				GMT->current.io.io_nan_ncols = 1;		/* Default is that single z column */
				GMT->current.setting.io_nan_mode = 1;	/* Plain -S */
				if (opt->arg[0] == 'r') GMT->current.setting.io_nan_mode = 2;
				GMT->common.s.active = TRUE;
				break;
#endif
			case 'N':	/* Nan-value */
				Ctrl->N.active = TRUE;
				if (opt->arg[0])
					Ctrl->N.value = (opt->arg[0] == 'N' || opt->arg[0] == 'n') ? GMT->session.d_NaN : atof (opt->arg);
				else {
					GMT_report (GMT, GMT_MSG_FATAL, "Syntax error -N option: Must specify value or NaN\n");
					n_errors++;
				}
				break;
			case 'W':	/* Add weight on output */
				Ctrl->W.active = TRUE;
				if (opt->arg[0]) Ctrl->W.weight = atof (opt->arg);
				break;
			case 'Z':	/* Control format */
				Ctrl->Z.active = TRUE;
				n_errors += GMT_parse_z_io (GMT, opt->arg, &Ctrl->Z);
					break;

			default:	/* Report bad options */
				n_errors += GMT_default_error (GMT, opt->option);
				break;
		}
	}
	
	GMT_init_z_io (GMT, Ctrl->Z.format, Ctrl->Z.repeat, Ctrl->Z.swab, Ctrl->Z.skip, Ctrl->Z.type, io);

	n_errors += GMT_check_condition (GMT, n_files == 0, "Syntax error: Must specify at least one input file\n");
#ifdef GMT_COMPAT
	n_errors += GMT_check_condition (GMT, n_files > 1 && Ctrl->E.active, "Syntax error: -E can only handle one input file\n");
	n_errors += GMT_check_condition (GMT, Ctrl->Z.active && Ctrl->E.active, "Syntax error: -E is not compatible with -Z\n");
#endif

	return (n_errors ? GMT_PARSE_ERROR : GMT_OK);
}

#define bailout(code) {GMT_Free_Options (mode); return (code);}
#define Return(code) {Free_grd2xyz_Ctrl (GMT, Ctrl); GMT_end_module (GMT, GMT_cpy); bailout (code);}

GMT_LONG GMT_grd2xyz (struct GMTAPI_CTRL *API, GMT_LONG mode, void *args)
{
	GMT_LONG error = FALSE, first = TRUE;
	GMT_LONG row, col, ij, gmt_ij, ok, n_suppressed = 0, n_total = 0;

	char header[GMT_BUFSIZ];

	double wesn[4], d_value, out[4], *x = NULL, *y = NULL;

	struct GMT_GRID *G = NULL;
	struct GMT_Z_IO io;
	struct GMT_OPTION *opt = NULL;
	struct GRD2XYZ_CTRL *Ctrl = NULL;
	struct GMT_CTRL *GMT = NULL, *GMT_cpy = NULL;
	struct GMT_OPTION *options = NULL;

	/*----------------------- Standard module initialization and parsing ----------------------*/

	if (API == NULL) return (GMT_Report_Error (API, GMT_NOT_A_SESSION));
	options = GMT_Prep_Options (API, mode, args);	if (API->error) return (API->error);	/* Set or get option list */

	if (!options || options->option == GMTAPI_OPT_USAGE) bailout (GMT_grd2xyz_usage (API, GMTAPI_USAGE));	/* Return the usage message */
	if (options->option == GMTAPI_OPT_SYNOPSIS) bailout (GMT_grd2xyz_usage (API, GMTAPI_SYNOPSIS));	/* Return the synopsis */

	/* Parse the command-line arguments */

	GMT = GMT_begin_module (API, "GMT_grd2xyz", &GMT_cpy);	/* Save current state */
	if (GMT_Parse_Common (API, "-VRbf:", "hos>" GMT_OPT("H"), options)) Return (API->error);
	Ctrl = New_grd2xyz_Ctrl (GMT);	/* Allocate and initialize a new control structure */
	if ((error = GMT_grd2xyz_parse (API, Ctrl, &io, options))) Return (error);
	
	/*---------------------------- This is the grd2xyz main code ----------------------------*/

	GMT_memcpy (wesn, GMT->common.R.wesn, 4, double);	/* Current -R setting, if any */

	if (GMT->common.b.active[GMT_OUT]) {
		if (Ctrl->Z.active && !io.binary) {
			GMT_report (GMT, GMT_MSG_FATAL, "Warning: -Z overrides -bo\n");
			GMT->common.b.active[GMT_OUT] = FALSE;
		}
#ifdef GMT_COMPAT
		if (Ctrl->E.active) {
			GMT_report (GMT, GMT_MSG_FATAL, "Warning: -E overrides -bo\n");
			GMT->common.b.active[GMT_OUT] = FALSE;
		}
#endif
	}
	else if (io.binary) GMT->common.b.active[GMT_OUT] = TRUE;

	if (GMT_Init_IO (API, GMT_IS_DATASET, GMT_IS_POINT, GMT_OUT, GMT_REG_STD_IF_NONE, options) != GMT_OK) {	/* Registers stdout, unless already set */
		Return (API->error);
	}
	if (GMT_Begin_IO (API, GMT_IS_DATASET, GMT_OUT) != GMT_OK) {	/* Enables data output and sets access mode */
		Return (API->error);
	}

	GMT->common.b.ncol[GMT_OUT] = (Ctrl->Z.active) ? 1 : ((Ctrl->W.active) ? 4 : 3);
	if ((error = GMT_set_cols (GMT, GMT_OUT, 0)) != GMT_OK) Return (error);
	out[3] = Ctrl->W.weight;
		
	for (opt = options; opt; opt = opt->next) {	/* Loop over arguments, skip options */ 

		if (opt->option != '<') continue;	/* We are only processing input files here */

		if ((G = GMT_Read_Data (API, GMT_IS_GRID, GMT_IS_FILE, GMT_IS_SURFACE, NULL, GMT_GRID_HEADER, opt->arg, NULL)) == NULL) {
			Return (API->error);
		}

		GMT_report (GMT, GMT_MSG_NORMAL, "Working on file %s\n", G->header->name);

		if (GMT_is_subset (GMT, G->header, wesn))	/* Subset requested; make sure wesn matches header spacing */
			GMT_err_fail (GMT, GMT_adjust_loose_wesn (GMT, wesn, G->header), "");

		if (GMT_Read_Data (API, GMT_IS_GRID, GMT_IS_FILE, GMT_IS_SURFACE, wesn, GMT_GRID_DATA, opt->arg, G) == NULL) {
			Return (API->error);	/* Get subset */
		}

		n_total += G->header->nm;

		GMT_err_fail (GMT, GMT_set_z_io (GMT, &io, G), opt->arg);

		if (Ctrl->Z.active) {	/* Write z-values only to stdout */
			PFL save = GMT->current.io.output;
			GMT_LONG previous = GMT->common.b.active[GMT_OUT], rst = FALSE;
			GMT->current.io.output = GMT_z_output;		/* Override and use chosen output mode */
			GMT->common.b.active[GMT_OUT] = io.binary;	/* May have to set binary as well */
			if (GMT->current.setting.io_nan_mode && GMT->current.io.io_nan_col[0] == GMT_Z) 
				{rst = TRUE; GMT->current.io.io_nan_col[0] = GMT_X;}	/* Since we dont do xy here, only z */
			for (ij = 0; ij < io.n_expected; ij++) {
				gmt_ij = io.get_gmt_ij (&io, G, ij);	/* Get the corresponding grid node */
				d_value = G->data[gmt_ij];
				if ((io.x_missing && io.gmt_i == io.x_period) || (io.y_missing && io.gmt_j == 0)) continue;
				if (Ctrl->N.active && GMT_is_dnan (d_value)) d_value = Ctrl->N.value;
				ok = GMT_Put_Record (API, GMT_WRITE_DOUBLE, &d_value);
				if (!ok) n_suppressed++;	/* Bad value caught by -s[r] */
			}
			GMT->current.io.output = save;			/* Reset pointer */
			GMT->common.b.active[GMT_OUT] = previous;	/* Reset binary */
			if (rst) GMT->current.io.io_nan_col[0] = GMT_Z;	/* Reset to what it was */
		}
#ifdef GMT_COMPAT
		else if (Ctrl->E.active) {	/* ESRI format */
			double slop;
			char *record = NULL, item[GMT_BUFSIZ];
			GMT_LONG n_alloc, len, rec_len;
			slop = 1.0 - (G->header->inc[GMT_X] / G->header->inc[GMT_Y]);
			if (!GMT_IS_ZERO (slop)) {
				GMT_report (GMT, GMT_MSG_FATAL, "Error: x_inc must equal y_inc when writing to ESRI format\n");
				Return (EXIT_FAILURE);
			}
			n_alloc = G->header->nx * 8;	/* Assume we only need 8 bytes per item (but we will allocate more if needed) */
			record = GMT_memory (GMT, NULL, G->header->nx, char);
			
			sprintf (record, "ncols %d\nnrows %d", G->header->nx, G->header->ny);
			GMT_Put_Record (API, GMT_WRITE_TEXT, record);	/* Write a text record */
			if (G->header->registration == GMT_PIXEL_REG) {	/* Pixel format */
				sprintf (record, "xllcorner ");
				sprintf (item, GMT->current.setting.format_float_out, G->header->wesn[XLO]);
				strcat  (record, item);
				GMT_Put_Record (API, GMT_WRITE_TEXT, record);	/* Write a text record */
				sprintf (record, "yllcorner ");
				sprintf (item, GMT->current.setting.format_float_out, G->header->wesn[YLO]);
				strcat  (record, item);
				GMT_Put_Record (API, GMT_WRITE_TEXT, record);	/* Write a text record */
			}
			else {	/* Gridline format */
				sprintf (record, "xllcenter ");
				sprintf (item, GMT->current.setting.format_float_out, G->header->wesn[XLO]);
				strcat  (record, item);
				GMT_Put_Record (API, GMT_WRITE_TEXT, record);	/* Write a text record */
				sprintf (record, "yllcenter ");
				sprintf (item, GMT->current.setting.format_float_out, G->header->wesn[YLO]);
				strcat  (record, item);
				GMT_Put_Record (API, GMT_WRITE_TEXT, record);	/* Write a text record */
			}
			sprintf (record, "cellsize ");
			sprintf (item, GMT->current.setting.format_float_out, G->header->inc[GMT_X]);
			strcat  (record, item);
			GMT_Put_Record (API, GMT_WRITE_TEXT, record);	/* Write a text record */
			sprintf (record, "nodata_value %d", irint (Ctrl->E.nodata));
			GMT_Put_Record (API, GMT_WRITE_TEXT, record);	/* Write a text record */
			GMT_row_loop (GMT, G, row) {	/* Scanlines, starting in the north (ymax) */
				rec_len = 0;
				GMT_col_loop (GMT, G, row, col, ij) {
					if (GMT_is_fnan (G->data[ij]))
						sprintf (item, "%d", irint (Ctrl->E.nodata));
					else if (Ctrl->E.floating)
						sprintf (item, GMT->current.setting.format_float_out, G->data[ij]);
					else
						sprintf (item, "%d", irint ((double)G->data[ij]));
					len = strlen (item);
					if ((rec_len + len + 1) >= n_alloc) {	/* Must get more memory */
						n_alloc <<= 1;
						record = GMT_memory (GMT, record, G->header->nx, char);
					}
					strcat (record, item);
					rec_len += len;
					if (col < (G->header->nx-1)) { strcat (record, " "); rec_len++;}
				}
				GMT_Put_Record (API, GMT_WRITE_TEXT, record);	/* Write a whole y line */
			}
			GMT_free (GMT, record);
		}
#endif
		else {	/* Regular x,y,z[,w] output */
			if (first && GMT_Init_IO (API, GMT_IS_DATASET, GMT_IS_POINT, GMT_OUT, GMT_REG_STD_IF_NONE, options) != GMT_OK) {	/* Establishes data output */
				Return (API->error);
			}

			x = GMT_memory (GMT, NULL, G->header->nx, double);
			y = GMT_memory (GMT, NULL, G->header->ny, double);

			/* Compute grid node positions once only */

			for (row = 0; row < G->header->ny; row++) y[row] = GMT_grd_row_to_y (GMT, row, G->header);
			for (col = 0; col < G->header->nx; col++) x[col] = GMT_grd_col_to_x (GMT, col, G->header);

			if (GMT->current.io.io_header[GMT_OUT] && first) {
				if (!G->header->x_units[0]) strcpy (G->header->x_units, "x");
				if (!G->header->y_units[0]) strcpy (G->header->y_units, "y");
				if (!G->header->z_units[0]) strcpy (G->header->z_units, "z");
				if (GMT->current.setting.io_lonlat_toggle[GMT_IN])
					sprintf (header, "# %s\t%s\t%s", G->header->y_units, G->header->x_units, G->header->z_units);
				else
					sprintf (header, "# %s\t%s\t%s", G->header->x_units, G->header->y_units, G->header->z_units);
				if (Ctrl->W.active) strcat (header, "\tweight");
				GMT_Put_Record (API, GMT_WRITE_TBLHEADER, header);	/* Write a header record */
				first = FALSE;
			}

			GMT_grd_loop (GMT, G, row, col, ij) {
				out[GMT_X] = x[col];	out[GMT_Y] = y[row];	out[GMT_Z] = G->data[ij];
				if (Ctrl->N.active && GMT_is_dnan (out[GMT_Z])) out[GMT_Z] = Ctrl->N.value;
				ok = GMT_Put_Record (API, GMT_WRITE_DOUBLE, out);		/* Write this to output */
				if (!ok) n_suppressed++;	/* Bad value caught by -s[r] */
			}
			GMT_free (GMT, x);
			GMT_free (GMT, y);
		}
	}

	if (GMT_End_IO (API, GMT_OUT, 0) != GMT_OK) {	/* Disables further data output */
		Return (API->error);
	}

	GMT_report (GMT, GMT_MSG_NORMAL, "%ld values extracted\n", n_total - n_suppressed);
	if (n_suppressed) {
		if (GMT->current.setting.io_nan_mode == 2)
			GMT_report (GMT, GMT_MSG_NORMAL, "%ld finite values suppressed\n", n_suppressed);
		else
			GMT_report (GMT, GMT_MSG_NORMAL, "%ld NaN values suppressed\n", n_suppressed);
	}

	Return (GMT_OK);
}
