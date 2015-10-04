/*
 * This file is part of the PulseView project.
 *
 * Copyright (C) 2012-2013 Joel Holdsworth <joel@airwebreathe.org.uk>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
 */

#include <cassert>
//#include <QWidgets>

#include <libsigrok/libsigrok.hpp>

#include "trigger.hpp"

 #include <pv/session.hpp>


//#include <pv/devices/hardwaredevice.hpp>


using std::list;
using std::map;
using std::string;

using Glib::ustring;
using Glib::Variant;
using Glib::VariantBase;

using sigrok::ConfigKey;
using sigrok::Error;

using pv::devices::HardwareDevice;

namespace pv {
namespace popups {

GeneralTab::GeneralTab(QWidget *parent)
    : QWidget(parent)
{
    QLabel *valueLabel = new QLabel(tr("Match Value (ch:val,ch:val)"));
    valueEdit = new QLineEdit("");

    QLabel *rangeLabel = new QLabel(tr("Match Range (ch:val,ch:val)"));
    rangeEdit = new QLineEdit("");

    QLabel *edgeLabel = new QLabel(tr("Match Edge (ch:val,ch:val)"));
    edgeEdit = new QLineEdit("");


    QLabel *aosLabel = new QLabel(tr("Arm on Step"));
    aosEdit = new QLineEdit("");

    QLabel *serialLabel = new QLabel(tr("Serial Mode?"));
    serialBox = new QCheckBox();

    /*delay;
	uint8_t repetitions;
	uint8_t data_ch;
	uint8_t clock_ch;
	uint8_t cycle_delay;*/


	QLabel *repetitionsLabel = new QLabel(tr("Repetitions"));
    repetitionsSpinBox = new QSpinBox;

    QLabel *cycledelayLabel = new QLabel(tr("Cycle Delay"));
    cycledelaySpinBox = new QSpinBox;

    QLabel *datachLabel = new QLabel(tr("Data Channel"));
    datachSpinBox = new QSpinBox;

    QLabel *clockchLabel = new QLabel(tr("Clock Channel"));
    clockchSpinBox = new QSpinBox;

    repetitionsSpinBox->setRange(1,100);
    repetitionsSpinBox->setSingleStep(1);
    repetitionsSpinBox->setValue(1);

    datachSpinBox->setRange(1,16);
    datachSpinBox->setSingleStep(1);
    datachSpinBox->setValue(1);

    clockchSpinBox->setRange(1,16);
    clockchSpinBox->setSingleStep(1);
    clockchSpinBox->setValue(1);

    cycledelaySpinBox->setRange(1,100);
    cycledelaySpinBox->setSingleStep(1);
    cycledelaySpinBox->setValue(1);


    QVBoxLayout *mainLayout = new QVBoxLayout;


    mainLayout->addWidget(serialLabel);
    mainLayout->addWidget(serialBox);

    mainLayout->addWidget(aosLabel);
    mainLayout->addWidget(aosEdit);

    mainLayout->addWidget(valueLabel);
    mainLayout->addWidget(valueEdit);

    mainLayout->addWidget(rangeLabel);
    mainLayout->addWidget(rangeEdit);

    mainLayout->addWidget(edgeLabel);
    mainLayout->addWidget(edgeEdit);

    QGridLayout *gridLayout = new QGridLayout();

    gridLayout->addWidget(repetitionsLabel,0,1);
    gridLayout->addWidget(repetitionsSpinBox,0,2);

    gridLayout->addWidget(cycledelayLabel,0,3);
    gridLayout->addWidget(cycledelaySpinBox,0,4);

    gridLayout->addWidget(datachLabel,1,1);
    gridLayout->addWidget(datachSpinBox,1,2);

    gridLayout->addWidget(clockchLabel,1,3);
    gridLayout->addWidget(clockchSpinBox,1,4);

	mainLayout->addLayout(gridLayout);
    mainLayout->addStretch(1);
    setLayout(mainLayout);

}


TriggerPopup::TriggerPopup(Session &session, pv::DeviceManager &device_manager, QWidget *parent) :
	Popup(parent),
	session_(session),
	device_manager_(device_manager)
{
	setWindowTitle(tr("Setup Trigger"));

	QLabel *trigOnLabel = new QLabel(tr("Trigger On (2,3,4...)"));
    trigOnEdit = new QLineEdit("2");
    
  

	tabWidget = new QTabWidget;
	triggerTab[0] = new GeneralTab(this);
    tabWidget->addTab(triggerTab[0],tr("Stage 0"));
    triggerTab[1] = new GeneralTab(this);
    tabWidget->addTab(triggerTab[1],tr("Stage 1"));
    triggerTab[2] = new GeneralTab(this);
    tabWidget->addTab(triggerTab[2],tr("Stage 2"));
    triggerTab[3] = new GeneralTab(this);
    tabWidget->addTab(triggerTab[3],tr("Stage 3"));
    triggerTab[4] = new GeneralTab(this);
    tabWidget->addTab(triggerTab[4],tr("Stage 4"));
    triggerTab[5] = new GeneralTab(this);
    tabWidget->addTab(triggerTab[5],tr("Stage 5"));
    triggerTab[6] = new GeneralTab(this);
    tabWidget->addTab(triggerTab[6],tr("Stage 6"));
    triggerTab[7] = new GeneralTab(this);
    tabWidget->addTab(triggerTab[7],tr("Stage 7"));
 



   	okButton = new QPushButton(tr("&Write to Device"));
    okButton->setDefault(true);

    //cancelButton = new QPushButton(tr("&Cancel"));
    //moreButton->setCheckable(true);
    //moreButton->setAutoDefault(false);

    buttonBox = new QDialogButtonBox(Qt::Horizontal);
    buttonBox->addButton(okButton, QDialogButtonBox::ActionRole);
    //buttonBox->addButton(cancelButton, QDialogButtonBox::ActionRole);


	QVBoxLayout *mainLayout = new QVBoxLayout;
	mainLayout->addWidget(trigOnLabel);
    mainLayout->addWidget(trigOnEdit);

    mainLayout->addWidget(tabWidget);
    mainLayout->addWidget(buttonBox);
    setLayout(mainLayout);


    connect(okButton, SIGNAL (released()), this, SLOT (handleOk()));

	//connect(button_box, SIGNAL(accepted()), this, SLOT(accept()));
	//connect(button_box, SIGNAL(rejected()), this, SLOT(reject()));

	
}

using sigrok::Trigger;
using sigrok::TriggerStage;
using sigrok::Context;
using sigrok::Channel;
using sigrok::TriggerMatchType;
// using pv::DeviceManager;

struct sr_trigger_stage {
	/** Starts at 0. */
	int stage;
	/** List of pointers to struct sr_trigger_match. */
	GSList *matches;
};

#define LEVEL_RISING 2
#define LEVEL_FALLING 3
#define LEVEL_LOW 0
#define LEVEL_HIGH 1

struct trigger_config {
	uint8_t trigger_on;
	struct trigger_stage_config *stages;
	uint8_t num_stages;
};

struct trigger_stage_config {
	uint8_t arm_on_step;
	uint16_t value;
	uint16_t range;
	uint16_t vmask;
	uint16_t edge;
	uint16_t emask;
	uint16_t delay;
	uint8_t repetitions;
	uint8_t data_ch;
	uint8_t clock_ch;
	uint8_t cycle_delay;
	uint8_t format;
};


void TriggerPopup::handleOk()
{
	struct trigger_config *trigger;

	if (!(trigger = g_try_new(struct trigger_config, 1))) {
        //sr_err("Trigger Config malloc failed");
	    return;
	}
	if (!(trigger->stages = g_try_new(struct trigger_stage_config, NUM_STAGES))) {
        //sr_err("Trigger Config malloc failed");
	    return;
	}
	trigger->trigger_on = trigOnEdit->text().toInt();
	int stagecount = 0;
	
	for (int x = 0; x < NUM_STAGES; x++)
	{
		struct trigger_stage_config *stage;
		stage = &(trigger->stages[x]);
		stage->value = 0;
		stage->vmask = 0;
		stage->range = 0;
		stage->edge = 0;
		stage->emask = 0;
		stage->delay = 0;
		stage->repetitions = 0;
		stage->data_ch = 0;
		stage->clock_ch = 0;
		stage->cycle_delay = 0;
		stage->format = 0;
		stage->arm_on_step = 0;

		if (triggerTab[x]->valueEdit->text().length() > 0)
		{
			stagecount++;

			
			QStringList pieces = triggerTab[x]->valueEdit->text().split(",");
			for (QString piece : pieces)
			{
				QStringList subpieces = piece.split(":");
				switch (subpieces.at(1).toStdString().c_str()[0])
				{
					case '0':
						stage->vmask |= (1 << subpieces.at(0).toInt());
						break;
					case '1':
						stage->value |= (1 << subpieces.at(0).toInt());
						stage->vmask |= (1 << subpieces.at(0).toInt());
						break;
					case 'r':
						stage->edge |= (1 << subpieces.at(0).toInt());
						stage->emask |= (1 << subpieces.at(0).toInt());
						break;
					case 'f':
						stage->emask |= (1 << subpieces.at(0).toInt());
						break;

				}
			}
		}	
	}
	trigger->num_stages = stagecount;
	
	session_.session()->dev_set_trigger(trigger);
	close();
}


} // namespace dialogs
} // namespace pv
