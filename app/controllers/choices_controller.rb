class ChoicesController < InheritedResources::Base
  respond_to :xml, :json
  actions :show, :index, :create, :update
  belongs_to :question
  has_scope :active, :boolean => true, :only => :index
  
  def index
    if params[:limit]
      @question = Question.find(params[:question_id])#, :include => :choices)
      @choices = Choice.find(:all, :conditions => {:question_id => @question.id}, :limit => params[:limit].to_i, :order => 'score DESC')
      #@choices = @question.choices(true).sort_by {|c| 0 - c.score }.first(params[:limit].to_i)#.active
    else
      @question = Question.find(params[:question_id], :include => :choices) #eagerloads ALL choices
      @choices = @question.choices(true)#.sort_by {|c| 0 - c.score }
    end
    index! do |format|
      format.xml { render :xml => params[:data].blank? ? @choices.to_xml(:methods => [:data, :votes_count]) : @choices.to_xml(:include => [:items], :methods => [:data, :votes_count])}
      format.json { render :json => params[:data].blank? ? @choices.to_json : @choices.to_json(:include => [:items]) }
    end

    # index! do |format|
    #   if !params[:voter_id].blank?
    #     format.xml { render :xml => User.find(params[:voter_id]).prompts_voted_on.to_xml(:include => [:items, :votes], 
    #                                                                                       :methods => [ :active_items_count, 
    #                                                                                                     :all_items_count, 
    #                                                                                                     :votes_count ]) }
    #     format.json { render :json => User.find(params[:voter_id]).prompts_voted_on.to_json(:include => [:items, :votes], 
    #                                                                         :methods => [ :active_items_count, 
    #                                                                                       :all_items_count, 
    #                                                                                       :votes_count ]) }
    #   else
    #     format.xml { render :xml => params[:data].blank? ? 
    #                                 @prompts.to_xml : 
    #                                 @prompts.to_xml(:include => [:items]) 
    #                                 }
    #     format.json { render :json => params[:data].blank? ? @prompts.to_json : @prompts.to_json(:include => [:items]) }
    #   end
    # end
  end
  
  def show
    @question = Question.find(params[:question_id])
    @prompt = @question.prompts.find(params[:id])
    show! do |format|
      format.xml { render :xml => @prompt.to_xml(:methods => [:left_choice_text, :right_choice_text])}
      format.json { render :json => @prompt.to_json(:methods => [:left_choice_text, :right_choice_text])}
    end
  end
  
  def single
    @question = current_user.questions.find(params[:question_id])
    @prompt = @question.prompts.pick
    show! do |format|
      format.xml { render :xml => @prompt.to_xml}
      format.json { render :json => @prompt.to_json}
    end
  end
  
  
  def create_from_abroad
    authenticate
    logger.info "inside create_from_abroad"

    @question = Question.find params[:question_id]
    # @visitor = Visitor.find_or_create_by_identifier(params['params']['sid'])
    # @item = current_user.items.create({:data => params['params']['data'], :creator => @visitor}
    # @choice = @question.choices.build(:item => @item, :creator => @visitor)

    respond_to do |format|
      if @choice = current_user.create_choice(params['params']['data'], @question, {:data => params['params']['data']})
        saved_choice_id = Proc.new { |options| options[:builder].tag!('saved_choice_id', @choice.id) }
        logger.info "successfully saved the choice #{@choice.inspect}"
        format.xml { render :xml => @question.picked_prompt.to_xml(:methods => [:left_choice_text, :right_choice_text], :procs => [saved_choice_id]), :status => :ok }
        format.json { render :json => @question.picked_prompt.to_json, :status => :ok }
      else
        format.xml { render :xml => @choice.errors, :status => :unprocessable_entity }
        format.json { render :json => @choice.errors, :status => :unprocessable_entity }
      end
    end
  end
    
  
  def skip
    voter = User.by_sid(params['params']['auto'])
    logger.info "#{voter.inspect} is skipping."
    @question = Question.find(params[:question_id])
    @prompt = @question.prompts.find(params[:id])
    respond_to do |format|
      if @skip = voter.skip(@prompt)
        format.xml { render :xml =>  @question.picked_prompt.to_xml(:methods => [:left_choice_text, :right_choice_text]), :status => :ok }
        format.json { render :json => @question.picked_prompt.to_json, :status => :ok }
      else
        format.xml { render :xml => c, :status => :unprocessable_entity }
        format.json { render :json => c, :status => :unprocessable_entity }
      end
    end
  end
end