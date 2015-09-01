/*
 * This file is part of the PulseView project.
 *
 * Copyright (C) 2013 Joel Holdsworth <joel@airwebreathe.org.uk>
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

#ifndef PULSEVIEW_PV_MARGINWIDGET_H
#define PULSEVIEW_PV_MARGINWIDGET_H

#include <QPoint>
#include <QWidget>

namespace pv {
namespace view {

class View;

class MarginWidget : public QWidget
{
	Q_OBJECT

public:
	MarginWidget(pv::view::View &parent);

public Q_SLOTS:
	virtual void clear_selection();

Q_SIGNALS:
	void selection_changed();

protected:
	pv::view::View &view_;
	QPoint mouse_point_;
	QPoint mouse_down_point_;
	bool dragging_;
};

} // namespace view
} // namespace pv

#endif // PULSEVIEW_PV_MARGINWIDGET_H
