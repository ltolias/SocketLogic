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

#ifndef PULSEVIEW_PV_TRIGGER_HPP
#define PULSEVIEW_PV_TRIGGER_HPP

#include <memory>

//#include <QComboBox>
#include <QDialog>
#include <QDialogButtonBox>
//#include <QFormLayout>
#include <QLineEdit>
//#include <QListWidget>
#include <QTabWidget>
#include <QLabel>
 #include <QSpinBox>
 #include <QCheckBox>
#include <QWidget>
#include <QVBoxLayout>
 #include <QGridLayout>
#include <QPushButton>
#include <QObject>
 #include <pv/devicemanager.hpp>

 #include <pv/widgets/popup.hpp>


#define NUM_STAGES 8

namespace sigrok {
class Driver;
}

namespace pv {
namespace devices {
class HardwareDevice;
}
}



// Q_DECLARE_METATYPE(std::shared_ptr<sigrok::Driver>);
// Q_DECLARE_METATYPE(std::shared_ptr<pv::devices::HardwareDevice>);

namespace pv {

class Session;


namespace popups {

class GeneralTab : public QWidget
{
    Q_OBJECT

public:
    explicit GeneralTab(QWidget *parent = 0);
    QLineEdit *aosEdit;
	QLineEdit *valueEdit;
	QLineEdit *rangeEdit;
	QLineEdit *edgeEdit;
	QCheckBox *serialBox;
	QSpinBox *repetitionsSpinBox;
	QSpinBox *cycledelaySpinBox;
	QSpinBox *clockchSpinBox;
	QSpinBox *datachSpinBox;

};


class TriggerPopup : public pv::widgets::Popup
{
	Q_OBJECT


public:
	TriggerPopup(Session &session, pv::DeviceManager &device_manager, QWidget *parent);

	

private:

	QDialogButtonBox *buttonBox;
	QPushButton *cancelButton;
	QPushButton *okButton;

	Session &session_;

	pv::DeviceManager &device_manager_;

	QTabWidget *tabWidget;

	GeneralTab *triggerTab[NUM_STAGES];

	QLineEdit *trigOnEdit;


private Q_SLOTS:
	void handleOk();

};

} // namespace dialogs
} // namespace pv

#endif // PULSEVIEW_PV_TRIGGER_HPP
