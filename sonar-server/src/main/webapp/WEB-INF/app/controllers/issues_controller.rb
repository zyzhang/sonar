#
# Sonar, entreprise quality control tool.
# Copyright (C) 2008-2013 SonarSource
# mailto:contact AT sonarsource DOT com
#
# SonarQube is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# SonarQube is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

class IssuesController < ApplicationController

  before_filter :init_options
  before_filter :load_user_filters, :only => [:index, :search, :filter, :manage]

  # GET /issues/index
  def index
    redirect_to :action => 'search'
  end

  # GET /issues/search
  def search
    if params[:id]
      @filter = find_filter(params[:id].to_i)
    else
      @filter = Internal.issues.createFilterFromMap(criteria_params)
    end

    @issue_query = Internal.issues.toQuery(criteria_params)
    @issues_result = Internal.issues.execute(@issue_query)
  end

  # Load existing filter
  # GET /issues/filter/<filter id>
  def filter
    require_parameters :id

    # criteria can be overridden
    # TODO ?
    #@filter.override_criteria(criteria_params)

    @filter = find_filter(params[:id].to_i)
    @issue_query = Internal.issues.toQuery(@filter.dataAsMap)
    @issues_result = Internal.issues.execute(@issue_query)
    @unchanged = true

    render :action => 'search'
  end

  # GET /issues/manage
  def manage
    @issue_query = Internal.issues.toQuery({})
  end

  # GET /issues/save_as_form?[id=<id>][&criteria]
  def save_as_form
    if params[:id].present?
      @filter = find_filter(params[:id])
    else
      @filter = Internal.issues.createFilterFromMap(criteria_params)
    end
    render :partial => 'issues/save_as_form'
  end

  # POST /issues/save_as?[id=<id>]&name=<name>[&parameters]
  def save_as
    verify_post_request
    options = {'id' => params[:id], 'name' => params[:name], 'description' => params[:description], 'data' => URI.unescape(params[:data]), 'shared' => params[:shared]=='true' }
    if params[:id].present?
      @filter = Internal.issues.updateIssueFilter(options)
    else
      filter_result = Internal.issues.createIssueFilter(options)
    end

    if filter_result.ok
      @filter = filter_result.get()
      render :text => @filter.id.to_s, :status => 200
    else
      @errors = filter_result.errors
      render :partial => 'issues/save_as_form', :status => 400
    end
  end

  # POST /issues/save?id=<id>&[criteria]
  def save
    verify_post_request
    require_parameters :id

    filter_result = Internal.issues.updateIssueFilterData(params[:id].to_i, criteria_params)
    if filter_result.ok
      @filter = filter_result.get()
      redirect_to :action => 'filter', :id => @filter.id.to_s
    else
      @errors = filter_result.errors

      @filter = find_filter(params[:id].to_i)
      @issue_query = Internal.issues.toQuery(@filter.dataAsMap)
      @issues_result = Internal.issues.execute(@issue_query)
      @unchanged = true

      render :action => 'search'
    end
  end

  # GET /issues/edit_form/<filter id>
  def edit_form
    require_parameters :id
    @filter = find_filter(params[:id].to_i)
    render :partial => 'issues/edit_form'
  end

  # POST /issues/edit/<filter id>?name=<name>&description=<description>&shared=<true|false>
  def edit
    verify_post_request

    existing_filter = find_filter(params[:id].to_i)
    options = {'id' => params[:id].to_s, 'name' => params[:name], 'description' => params[:description], 'data' => existing_filter.data, 'shared' => params[:shared]=='true' }
    filter_result = Internal.issues.updateIssueFilter(options)
    if filter_result.ok
      @filter = filter_result.get()
      render :text => @filter.id.to_s, :status => 200
    else
      @errors = filter_result.errors
      @filter = find_filter(params[:id].to_i)
      render :partial => 'issues/edit_form', :status => 400
    end
  end


  private

  def init_options
    @options_for_statuses = Internal.issues.listStatus().map {|s| [message('issue.status.' + s), s]}
    @options_for_resolutions = Internal.issues.listResolutions().map {|s| [message('issue.resolution.' + s), s]}
  end

  def load_user_filters
    @my_filters = Internal.issues.findIssueFiltersForUser()
  end

  def find_filter(id)
    Internal.issues.findIssueFilter(id)
  end

  def criteria_params
    criteria = params
    criteria.delete('controller')
    criteria.delete('action')
    criteria.delete('search')
    criteria.delete('edit')
    criteria.delete('pageSize')
    criteria
  end

end